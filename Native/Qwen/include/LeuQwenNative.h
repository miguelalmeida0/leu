#pragma once
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct leu_qwen_request leu_qwen_request;
typedef struct {
    int32_t prompt_tokens;
    int32_t output_tokens;
    double load_ms;
    double prompt_ms;
    double first_token_ms;
    double total_ms;
    uint64_t peak_observed_footprint;
} leu_qwen_metrics;
leu_qwen_request * leu_qwen_create(void);
// Cancellation is the only call allowed concurrently with run. Destroy only
// after run returns; no mutable model/context state escapes this boundary.
void leu_qwen_cancel(leu_qwen_request * request);
void leu_qwen_destroy(leu_qwen_request * request);
// CPU is a development comparison only. Shipping iOS callers must pass 1.
// Return: 0 complete, 1 cancelled, 2 busy, 3 context limit, 4 failure,
// 5 output limit, 6 memory budget. Output is empty on every failure.
int leu_qwen_run(leu_qwen_request *, const char * model_path,
    const char * system_prompt, const char * input_json, const char * schema_json,
    int context_tokens, int output_tokens, int use_metal,
    uint64_t maximum_footprint, char * output, int output_capacity,
    leu_qwen_metrics * metrics);
const char * leu_qwen_runtime_commit(void);
#ifdef __cplusplus
}
#endif
