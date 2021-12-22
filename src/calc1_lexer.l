/* =========================== BOILERPLATE SECTION ===========================*/

/* This is to avoid compiler warnings about unused functions. More options are
   noyyalloc noyyrealloc noyyfree. */
%option noyywrap nounput noinput

/* Thread safe scanner */
%option reentrant

/* To avoid symbol name conflicts with multiple lexers */
%option prefix="calc1_"

/* Automake's ylwrap expexts the output to have this name */
%option outfile="lex.yy.c"

/* Makes a Bison-compatible yylex */
%option bison-bridge

%{
#include <stdio.h>
#include "calc1_parser.h"

/* Unknown why this is required despite using prefix */
#define YYSTYPE CALC1_STYPE

%}

/* ========================= NON-BOILERPLATE SECTION =========================*/
%%

[ \t]	; // ignore all whitespace
[0-9]+\.[0-9]+  { yylval->fval = atof(yytext); return CALC1_T_FLOAT; }
[0-9]+          { yylval->ival = atoi(yytext); return CALC1_T_INT; }
"\0"            { return CALC1_T_END; }
"+"             { return CALC1_T_PLUS; }
"-"             { return CALC1_T_MINUS; }
"*"             { return CALC1_T_MULTIPLY; }
"/"             { return CALC1_T_DIVIDE; }
"("             { return CALC1_T_LEFT; }
")"             { return CALC1_T_RIGHT; }

.               { return *yytext; } // Return anything else, should give syntax error

%%
