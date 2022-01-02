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

re_quote    '
re_key      [[:alnum:]\.\-]+
re_value    (\\.|[^'])+
re_operator (!?[:@])

%x IN_CRITERIA IN_CRITERIA_VALUE

%%

{re_quote} { BEGIN IN_CRITERIA; return DAAP_T_QUOTE; }

<IN_CRITERIA>{re_key}/{re_operator} { yylval->str = strdup(yytext); return DAAP_T_KEY; }
<IN_CRITERIA>{re_operator} { BEGIN IN_CRITERIA_VALUE; return (*yytext == '!' ? DAAP_T_NOT_EQUAL : DAAP_T_EQUAL); }
<IN_CRITERIA>. { return *yytext; } // Return anything else, should give syntax error

<IN_CRITERIA_VALUE>{re_value}/{re_quote} { yylval->str = strdup(yytext); return DAAP_T_VALUE; }
<IN_CRITERIA_VALUE>{re_quote} { BEGIN INITIAL; return DAAP_T_QUOTE; }
<IN_CRITERIA_VALUE>. { return *yytext; } // Return anything else, should give syntax error

"\0"            { return DAAP_T_END; }
"+"|" "         { return DAAP_T_AND; }
","             { return DAAP_T_OR; }
"("             { return DAAP_T_LEFT; }
")"             { return DAAP_T_RIGHT; }
"\r"?"\n"       { return DAAP_T_NEWLINE; }
.               { return *yytext; } // Return anything else, should give syntax error

%%

int daap_lex_cb(char *input, void (*cb)(int, const char *))
{
  int ret;
  yyscan_t scanner;
  YY_BUFFER_STATE buf;
  YYSTYPE val;

  if ((ret = daap_lex_init(&scanner)) != 0)
    return ret;

  buf = daap__scan_string(input, scanner);

  while ((ret = daap_lex(&val, scanner)) > 0)
    cb(ret, daap_get_text(scanner));

  daap__delete_buffer(buf, scanner);
  daap_lex_destroy(scanner);
  return 0;
}
