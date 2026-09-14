"""Narrow SwiftUI Section overload guard, not a replacement for Apple typechecking."""
from pathlib import Path
import re


def mask_literals_and_comments(source: str) -> str:
    """Keep offsets/newlines while masking ordinary/raw strings and nested comments."""
    masked = list(source)

    def blank(start: int, end: int) -> None:
        for index in range(start, end):
            if masked[index] != '\n':
                masked[index] = ' '

    index = 0
    while index < len(source):
        if source.startswith('//', index):
            end = source.find('\n', index)
            end = len(source) if end == -1 else end
            blank(index, end); index = end
        elif source.startswith('/*', index):
            start = index; index += 2; depth = 1
            while index < len(source) and depth:
                if source.startswith('/*', index):
                    depth += 1; index += 2
                elif source.startswith('*/', index):
                    depth -= 1; index += 2
                else:
                    index += 1
            blank(start, index)
        else:
            literal = re.match(r'(#+)?("""|")', source[index:])
            if not literal:
                index += 1
                continue
            start = index
            hashes, quotes = literal.group(1) or '', literal.group(2)
            index += len(literal.group(0))
            closing = quotes + hashes
            escape = '\\' + hashes
            while index < len(source):
                if source.startswith(escape, index):
                    index = min(len(source), index + len(escape) + 1)
                elif source.startswith(closing, index):
                    index += len(closing)
                    break
                else:
                    index += 1
            blank(start, index)
    return ''.join(masked)


def close_delimiter(code: str, start: int, opening: str, closing: str) -> int | None:
    depth = 0
    for index in range(start, len(code)):
        if code[index] == opening:
            depth += 1
        elif code[index] == closing:
            depth -= 1
            if depth == 0:
                return index
    return None


def violations(source: str) -> list[int]:
    """Reject Section(title) { ... } footer/header: { ... }; return line numbers.

    Only the unlabeled-title overload is checked. Other Section APIs are left to
    SwiftUI's compiler. The named-title initializer requires Footer == EmptyView.
    """
    code = mask_literals_and_comments(source)
    failures = []
    for match in re.finditer(r'\bSection\s*\(', code):
        start = code.find('(', match.start())
        end = close_delimiter(code, start, '(', ')')
        if end is None or ':' in code[start + 1:end]:
            continue
        body = end + 1
        while body < len(code) and code[body].isspace():
            body += 1
        if body == len(code) or code[body] != '{':
            continue
        close = close_delimiter(code, body, '{', '}')
        if close is not None and re.match(r'\s*(?:header|footer)\s*:\s*\{', code[close + 1:]):
            failures.append(source.count('\n', 0, match.start()) + 1)
    return failures


def check(root: Path) -> list[str]:
    return [
        f'{path.relative_to(root)}:{line}: Section(title) cannot accept a header/footer trailing closure; '
        'use Section { ... } header: { Text(title) } footer: { ... }'
        for path in sorted((root / 'Shelf').rglob('*.swift'))
        for line in violations(path.read_text())
    ]
