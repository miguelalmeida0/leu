#include "LeuQwenNative.h"
#include "llama.h"
#include "chat.h"
#include "log.h"
#include "json-schema-to-grammar.h"
#include <atomic>
#include <chrono>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <vector>
#include <mach/mach.h>

struct leu_qwen_request { std::atomic<bool> cancelled{false}; };
static std::mutex inference;
static std::once_flag initialized;
using Clock = std::chrono::steady_clock;
static double elapsed(Clock::time_point start) {
    return std::chrono::duration<double, std::milli>(Clock::now()-start).count();
}
static uint64_t footprint() {
    task_vm_info_data_t info{};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) return 0;
    return info.phys_footprint;
}
static bool abort_inference(void * data) {
    return static_cast<leu_qwen_request *>(data)->cancelled.load();
}
// No source text, generated text, filenames or prompts in production logs.
static void discard_log(ggml_log_level, const char *, void *) {}
extern "C" leu_qwen_request * leu_qwen_create() { return new leu_qwen_request; }
extern "C" void leu_qwen_cancel(leu_qwen_request * r) { if (r) r->cancelled.store(true); }
extern "C" void leu_qwen_destroy(leu_qwen_request * r) { delete r; }
extern "C" const char * leu_qwen_runtime_commit() { return "4c9233c034fc450dcf34c7c0988aebe6da5cdf1a"; }

extern "C" int leu_qwen_run(leu_qwen_request * r, const char * path,
    const char * system, const char * input, const char * schema,
    int context, int allowance, int metal, uint64_t budget,
    char * output, int capacity, leu_qwen_metrics * metrics) {
    if (!r || !path || !system || !input || !schema || !output || capacity < 2 || !metrics) return 4;
    output[0] = 0; *metrics = {};
    if (std::strlen(input) > 65536 || std::strlen(system) > 8192 || std::strlen(schema) > 32768) return 3;
    if ((context != 2048 && context != 4096) || allowance < 256 || allowance > 512 || !budget) return 4;
    std::unique_lock<std::mutex> lock(inference, std::try_to_lock);
    if (!lock.owns_lock()) return 2; // No queued native requests.
    const auto start = Clock::now();
    auto memory_ok = [&] {
        const auto current = footprint();
        metrics->peak_observed_footprint = std::max(metrics->peak_observed_footprint, current);
        return current != 0 && current < budget;
    };
    try {
        if (r->cancelled.load()) return 1;
        if (!memory_ok()) return 6;
        std::call_once(initialized, [] { common_log_set_verbosity_thold(-1); llama_log_set(discard_log, nullptr); llama_backend_init(); });
        auto mp = llama_model_default_params();
        ggml_backend_dev_t no_devices[] = {nullptr};
        if (!metal) mp.devices = no_devices;
        mp.n_gpu_layers = metal ? 99 : 0;
        mp.progress_callback = [](float, void * data) { return !abort_inference(data); };
        mp.progress_callback_user_data = r;
        std::unique_ptr<llama_model, decltype(&llama_model_free)> model(llama_model_load_from_file(path, mp), llama_model_free);
        if (!model) return r->cancelled.load() ? 1 : 4;
        metrics->load_ms = elapsed(start);
        if (!memory_ok()) return 6;
        const auto * vocab = llama_model_get_vocab(model.get());
        auto templates = common_chat_templates_init(model.get(), "");
        common_chat_templates_inputs ci;
        common_chat_msg sys, user;
        sys.role = "system"; sys.content = system;
        user.role = "user"; user.content = input;
        ci.messages = {sys, user}; ci.enable_thinking = false;
        ci.chat_template_kwargs["enable_thinking"] = "false";
        ci.use_jinja = true; ci.add_generation_prompt = true;
        const auto formatted = common_chat_templates_apply(templates.get(), ci);
        const int needed = -llama_tokenize(vocab, formatted.prompt.data(), (int)formatted.prompt.size(), nullptr, 0, true, true);
        if (needed <= 0) return 4;
        metrics->prompt_tokens = needed;
        if (needed + allowance > context) return 3; // Never truncate input.
        std::vector<llama_token> tokens(needed);
        if (llama_tokenize(vocab, formatted.prompt.data(), (int)formatted.prompt.size(), tokens.data(), needed, true, true) != needed) return 4;
        auto cp = llama_context_default_params();
        cp.n_ctx = context; cp.n_batch = 128; cp.n_ubatch = 128;
        cp.n_threads = 4; cp.n_threads_batch = 4; cp.op_offload = metal != 0;
        cp.no_perf = false; cp.abort_callback = abort_inference; cp.abort_callback_data = r;
        std::unique_ptr<llama_context, decltype(&llama_free)> ctx(llama_init_from_model(model.get(), cp), llama_free);
        if (!ctx) return r->cancelled.load() ? 1 : 4;
        const auto grammar = json_schema_to_grammar(common_json::parse(schema));
        std::unique_ptr<llama_sampler, decltype(&llama_sampler_free)> sampler(llama_sampler_chain_init(llama_sampler_chain_default_params()), llama_sampler_free);
        auto * grammar_sampler = llama_sampler_init_grammar(vocab, grammar.c_str(), "root");
        if (!grammar_sampler) return 4;
        llama_sampler_chain_add(sampler.get(), grammar_sampler);
        llama_sampler_chain_add(sampler.get(), llama_sampler_init_greedy());
        const auto prompt_start = Clock::now();
        for (int pos = 0; pos < needed; pos += 128) {
            if (r->cancelled.load()) return 1;
            if (!memory_ok()) return 6;
            auto batch = llama_batch_get_one(tokens.data()+pos, std::min(128, needed-pos));
            if (llama_decode(ctx.get(), batch)) return r->cancelled.load() ? 1 : 4;
        }
        metrics->prompt_ms = elapsed(prompt_start);
        std::string result;
        for (int i = 0; i < allowance; ++i) {
            if (r->cancelled.load()) return 1;
            if (!memory_ok()) return 6;
            auto token = llama_sampler_sample(sampler.get(), ctx.get(), -1);
            if (i == 0) metrics->first_token_ms = elapsed(start);
            if (llama_vocab_is_eog(vocab, token)) {
                // Completion, not merely syntactically plausible partial output.
                auto parsed = common_json::parse(result);
                if (!parsed.is_object()) return 4;
                std::memcpy(output, result.c_str(), result.size()+1);
                metrics->total_ms = elapsed(start);
                return 0;
            }
            char piece[512];
            int n = llama_token_to_piece(vocab, token, piece, sizeof(piece), 0, false);
            if (n < 0 || result.size()+n+1 >= (size_t)capacity) return 5;
            result.append(piece, n); metrics->output_tokens++;
            auto batch = llama_batch_get_one(&token, 1);
            if (llama_decode(ctx.get(), batch)) return r->cancelled.load() ? 1 : 4;
        }
        return 5;
    } catch (...) { return r->cancelled.load() ? 1 : 4; }
    // RAII releases sampler, context, and weights on every return, before Swift
    // destroys the cancellation handle. No model survives an idle/background gap.
}
