FILE = nil
LEX  = nil
TK0  = nil
TK1  = nil
LIN  = nil

OPS = {
    cs = { '+', '-', '*', '/', '%', '>', '<', '=', '|', '&', '?', '!' ,'#' },
    vs = {
        '#',
        '=', --'=>', '->',
        '==', '!=',
        '>', '<', '>=', '<=',
        '||', '&&',
        '+', '-', '*', '/', '%',
        '!', --'?',
        --'++',
    },
    unos = {
        '-', '#', '!'
    },
    bins = {
        '==', '!=',
        '>', '<', '>=', '<=',
        '||', '&&',
        '+', '-', '*', '/', '%',
        --'++',
    },
    sufs = {
        '[', '.', '('
    },
}

KEYS = {
    'await', 'break', 'do', 'catch', 'coro', 'defer',
    'data', 'else', 'emit', 'escape', 'every', 'false', 'func', 'if',
    'in', 'loop', 'match', 'nil', 'par', 'par_and', 'par_or',
    'resume', 'return', 'set', 'spawn', 'task', 'tasks', 'test',
    'throw', 'true', 'until', 'val', 'var', 'yield', 'with', 'while'
}
