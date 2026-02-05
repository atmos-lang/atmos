FILE = nil
LEX  = nil
TK0  = nil
TK1  = nil
LIN  = nil
SEP  = nil
_n_  = nil
_l_  = nil

function init ()
    SEP = 1
    _n_ = 0
    _l_ = 1
end

function N ()
    _n_ = _n_ + 1
    return _n_
end

SYMS = { '{', '}', '(', ')', '[', ']', ',', '\\' }

KEYS = {
    'await', 'catch', 'defer', 'do', 'else', 'emit', 'every', 'false', 'func',
    'if', 'ifs', 'in', 'loop', 'match', 'nil', 'par', 'par_and', 'par_or',
    'pin', 'set', 'spawn', 'tasks', 'test', 'toggle', 'true', 'val', 'var',
    'watching', 'where', 'with',
    -- 'break', 'escape', 'it', 'pub', 'return', 'skip', 'task',
    -- 'throw', 'until', 'while'
}

OPS = {
    cs = { '+', '-', '*', '/', '%', '>', '<', '=', '|', '&', '?', '!' ,'#', '~' },
    vs = {
        '#',
        '=', '=>',
        '==', '!=', '===', '=!=',
        '>', '<', '>=', '<=',
        '||', '&&',
        '+', '-', '*', '**', '/', '//', '%',
        '!',
        '++',
        '~~', '!~',
        '??', '!?',
        '?>', '!>',
        '->', '-->', '<-', '<--',
    },
    unos = {
        '-', '#', '!'
    },
    bins = {
        '==', '!=', '===', '=!=',
        '??', '!?',
        '+', '-', '*', '**', '/', '//', '%',
        '>', '<', '>=', '<=',
        '||', '&&',
        '++',
        '?>', '!>',
        '~~', '!~',
    },
    lua = {
        ['!']  = 'not',
        ['!='] = '~=',
        ['||'] = 'or',
        ['&&'] = 'and',
        ['**'] = '^',
    }
}
