/* =========================== BOILERPLATE SECTION ===========================*/

/* This is to avoid compiler warnings about unused functions. More options are
   noyyalloc noyyrealloc noyyfree. */
%option noyywrap nounput noinput

/* Thread safe scanner */
%option reentrant

/* To avoid symbol name conflicts with multiple lexers */
%option prefix="daap_"

/* Automake's ylwrap expexts the output to have this name */
%option outfile="lex.yy.c"

/* Makes a Bison-compatible yylex */
%option bison-bridge

%{
#include <stdio.h>
#include "daap_parser.h"

/* Unknown why this is required despite using prefix */
#define YYSTYPE DAAP_STYPE

%}

/* ========================= NON-BOILERPLATE SECTION =========================*/
%%

[ \t]	; // ignore all whitespace
[0-9]+\.[0-9]+  { yylval->fval = atof(yytext); return DAAP_T_FLOAT; }
[0-9]+          { yylval->ival = atoi(yytext); return DAAP_T_INT; }
"\0"            { return DAAP_T_END; }
"+"             { return DAAP_T_PLUS; }
"-"             { return DAAP_T_MINUS; }
"*"             { return DAAP_T_MULTIPLY; }
"/"             { return DAAP_T_DIVIDE; }
"("             { return DAAP_T_LEFT; }
")"             { return DAAP_T_RIGHT; }

.               { return *yytext; } // Return anything else, should give syntax error

%%
