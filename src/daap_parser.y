/* =========================== BOILERPLATE SECTION ===========================*/

/* No global variables and yylex has scanner as argument */
%define api.pure true

/* Change prefix of symbols from yy to avoid clashes with any other parsers we
   may want to link */
%define api.prefix {daap_}

/* Gives better errors than "syntax error" */
%define parse.error verbose

/* Adds output parameter to the parser */
%parse-param {struct daap_result *result}

/* Adds "scanner" as argument to the parses calls to yylex, which is required
   when the lexer is in reentrant mode. The type is void because caller caller
   shouldn't need to know about yyscan_t */
%param {void *scanner}

/* Convenience function for caller to use instead of interfacing with lexer and
   parser directly */
%code provides {
int daap_lex_parse(struct daap_result *result, char *input);
}

/* Implementation of the convenience function and the parsing error function
   required by Bison */
%code {
  #define YYSTYPE DAAP_STYPE
  #include "daap_lexer.h"

  int daap_lex_parse(struct daap_result *result, char *input)
  {
    YY_BUFFER_STATE buffer;
    yyscan_t scanner;
    int retval = -1;
    int ret;

    result->errmsg[0] = '\0'; // For safety

    ret = daap_lex_init(&scanner);
    if (ret != 0)
      goto error_init;

    buffer = daap__scan_string(input, scanner);
    if (!buffer)
      goto error_buffer;

    ret = daap_parse(result, scanner);
    if (ret != 0)
      goto error_parse;

    retval = 0;

   error_parse:
    daap__delete_buffer(buffer, scanner);
   error_buffer:
    daap_lex_destroy(scanner);
   error_init:
    return retval;
  }

  void daap_error(struct daap_result *result, yyscan_t scanner, const char *msg)
  {
    snprintf(result->errmsg, sizeof(result->errmsg), "%s", msg);
  }
}

/* ========================= NON-BOILERPLATE SECTION =========================*/

/* Includes required by the parser rules */
%code top {
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
}

/* Definition of struct that will hold the parsing result */
%code requires {
struct daap_result {
  char str[32];
  int ival;
  float fval;
  char errmsg[128];
};
}

%union {
  int ival;
  float fval;
}

%token DAAP_T_END 0
%token<ival> DAAP_T_INT
%token<fval> DAAP_T_FLOAT
%token DAAP_T_PLUS DAAP_T_MINUS DAAP_T_MULTIPLY DAAP_T_DIVIDE DAAP_T_LEFT DAAP_T_RIGHT
%left DAAP_T_PLUS DAAP_T_MINUS
%left DAAP_T_MULTIPLY DAAP_T_DIVIDE

%type<ival> expression
%type<fval> mixed_expression

%start calculation

%%

calculation:
  | calculation mixed_expression DAAP_T_END           { snprintf(result->str, sizeof(result->str), "%g", $2); result->ival = (int)$2; result->fval = $2; }
  | calculation expression DAAP_T_END                 { snprintf(result->str, sizeof(result->str), "%d", $2); result->ival = $2;      result->fval = (float)$2; }
;

mixed_expression: DAAP_T_FLOAT                        { $$ = $1; }
  | mixed_expression DAAP_T_PLUS mixed_expression     { $$ = $1 + $3; }
  | mixed_expression DAAP_T_MINUS mixed_expression    { $$ = $1 - $3; }
  | mixed_expression DAAP_T_MULTIPLY mixed_expression { $$ = $1 * $3; }
  | mixed_expression DAAP_T_DIVIDE mixed_expression   { $$ = $1 / $3; }
  | DAAP_T_LEFT mixed_expression DAAP_T_RIGHT         { $$ = $2; }
  | expression DAAP_T_PLUS mixed_expression           { $$ = $1 + $3; }
  | expression DAAP_T_MINUS mixed_expression          { $$ = $1 - $3; }
  | expression DAAP_T_MULTIPLY mixed_expression       { $$ = $1 * $3; }
  | expression DAAP_T_DIVIDE mixed_expression         { $$ = $1 / $3; }
  | mixed_expression DAAP_T_PLUS expression           { $$ = $1 + $3; }
  | mixed_expression DAAP_T_MINUS expression          { $$ = $1 - $3; }
  | mixed_expression DAAP_T_MULTIPLY expression       { $$ = $1 * $3; }
  | mixed_expression DAAP_T_DIVIDE expression         { $$ = $1 / $3; }
  | expression DAAP_T_DIVIDE expression               { $$ = $1 / (float)$3; }
;

expression: DAAP_T_INT                                { $$ = $1; }
  | expression DAAP_T_PLUS expression                 { $$ = $1 + $3; }
  | expression DAAP_T_MINUS expression                { $$ = $1 - $3; }
  | expression DAAP_T_MULTIPLY expression             { $$ = $1 * $3; }
  | DAAP_T_LEFT expression DAAP_T_RIGHT               { $$ = $2; }
;

%%

