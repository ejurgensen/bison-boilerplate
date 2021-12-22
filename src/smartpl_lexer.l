/* =========================== BOILERPLATE SECTION ===========================*/

/* This is to avoid compiler warnings about unused functions. More options are
   noyyalloc noyyrealloc noyyfree. */
%option noyywrap nounput noinput

/* Thread safe scanner */
%option reentrant

/* To avoid symbol name conflicts with multiple lexers */
%option prefix="smartpl_"

/* Automake's ylwrap expexts the output to have this name */
%option outfile="lex.yy.c"

/* Makes a Bison-compatible yylex */
%option bison-bridge

%{
#include <stdio.h>
#include "smartpl_parser.h"

/* Unknown why this is required despite using prefix */
#define YYSTYPE SMARTPL_STYPE

%}

/* ========================= NON-BOILERPLATE SECTION =========================*/
%%

[ \t]	; // ignore all whitespace
"is"            { return SMARTPL_T_IS; }
"artist"        { return SMARTPL_T_STRTAG; }

.               { return *yytext; } // Return anything else, should give syntax error

%%
