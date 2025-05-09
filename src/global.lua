LEX = nil
TK0 = nil
TK1 = nil

OPS = {
    cs = { '+', '-', '*', '/', '%', '>', '<', '=', '|', '&', '?', '!' ,'#' },
    vs = {
        "#",
        "=", --"=>", "->",
        "==", "!=",
        ">", "<", ">=", "<=",
        "||", "&&",
        "+", "-", "*", "/", "%",
        "!", --"?",
        --"++",
    },
    unos = {
        "-", "#", "!"
    },
    bins = {
        "==", "!=",
        ">", "<", ">=", "<=",
        "||", "&&",
        "+", "-", "*", "/", "%",
        --"++",
    },
    sufs = {
        "[", ".", "("
    },
}

KEYS = {
    "await", "break", "do", "catch", "coro", "create", "defer",
    "data", "else", "emit", "escape", "every", "false", "func", "if",
    "in", "it", "loop", "match", "nil", "par", "par_and", "par_or",
    "resume", "return", "set", "spawn", "start", "task", "test",
    "throw", "true", "until", "var", "yield", "with", "while"
}
