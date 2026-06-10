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

SYMS = { '{', '}', '(', ')', '[', ']', ',', '\\', '@' }

-- TODO: RESERVED TAGS
--[[
  Await tags: or and not until while tasks clock
  Task modes: any all
  Event field keys: tag ms now mode tasks (internal: _ms _now _ ret)
  Clock fields: h min s ms
  Type names (??/!?): nil boolean number string function thread table task tasks
]]

KEYS = {
    'await', 'catch', 'defer', 'do', 'else', 'emit', 'false', 'func',
    'if', 'ifs', 'in', 'loop', 'match', 'nil', 'on', 'par', 'par_and', 'par_or',
    'pin', 'set', 'spawn', 'tasks', 'test', 'thread', 'toggle', 'true', 'val',
    'var', 'watching', 'where', 'with',
    -- 'abort', 'break', 'escape', 'it', 'pub', 'return', 'skip', 'task',
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
