/* =========================== BOILERPLATE SECTION ===========================*/

/* No global variables and yylex has scanner as argument */
%define api.pure true

/* Change prefix of symbols from yy to avoid clashes with any other parsers we
   may want to link */
%define api.prefix {calc1_}

/* Gives better errors than "syntax error" */
%define parse.error verbose

/* Adds output parameter to the parser */
%parse-param {struct calc1_result *result}

/* Adds "scanner" as argument to the parses calls to yylex, which is required
   when the lexer is in reentrant mode. The type is void because caller caller
   shouldn't need to know about yyscan_t */
%param {void *scanner}

/* Convenience function for caller to use instead of interfacing with lexer and
   parser directly */
%code provides {
int calc1_lex_parse(struct calc1_result *result, char *input);
}

/* Implementation of the convenience function and the parsing error function
   required by Bison */
%code {
  #define YYSTYPE CALC1_STYPE
  #include "calc1_lexer.h"

  int calc1_lex_parse(struct calc1_result *result, char *input)
  {
    YY_BUFFER_STATE buffer;
    yyscan_t scanner;
    int retval = -1;
    int ret;

    result->errmsg[0] = '\0'; // For safety

    ret = calc1_lex_init(&scanner);
    if (ret != 0)
      goto error_init;

    buffer = calc1__scan_string(input, scanner);
    if (!buffer)
      goto error_buffer;

    ret = calc1_parse(result, scanner);
    if (ret != 0)
      goto error_parse;

    retval = 0;

   error_parse:
    calc1__delete_buffer(buffer, scanner);
   error_buffer:
    calc1_lex_destroy(scanner);
   error_init:
    return retval;
  }

  void calc1_error(struct calc1_result *result, yyscan_t scanner, const char *msg)
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
struct calc1_result {
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

%token CALC1_T_END 0
%token<ival> CALC1_T_INT
%token<fval> CALC1_T_FLOAT
%token CALC1_T_PLUS CALC1_T_MINUS CALC1_T_MULTIPLY CALC1_T_DIVIDE CALC1_T_LEFT CALC1_T_RIGHT
%left CALC1_T_PLUS CALC1_T_MINUS
%left CALC1_T_MULTIPLY CALC1_T_DIVIDE

%type<ival> expression
%type<fval> mixed_expression

%start calculation

%%

calculation:
  | calculation mixed_expression CALC1_T_END           { snprintf(result->str, sizeof(result->str), "%g", $2); result->ival = (int)$2; result->fval = $2; }
  | calculation expression CALC1_T_END                 { snprintf(result->str, sizeof(result->str), "%d", $2); result->ival = $2;      result->fval = (float)$2; }
;

mixed_expression: CALC1_T_FLOAT                        { $$ = $1; }
  | mixed_expression CALC1_T_PLUS mixed_expression     { $$ = $1 + $3; }
  | mixed_expression CALC1_T_MINUS mixed_expression    { $$ = $1 - $3; }
  | mixed_expression CALC1_T_MULTIPLY mixed_expression { $$ = $1 * $3; }
  | mixed_expression CALC1_T_DIVIDE mixed_expression   { $$ = $1 / $3; }
  | CALC1_T_LEFT mixed_expression CALC1_T_RIGHT         { $$ = $2; }
  | expression CALC1_T_PLUS mixed_expression           { $$ = $1 + $3; }
  | expression CALC1_T_MINUS mixed_expression          { $$ = $1 - $3; }
  | expression CALC1_T_MULTIPLY mixed_expression       { $$ = $1 * $3; }
  | expression CALC1_T_DIVIDE mixed_expression         { $$ = $1 / $3; }
  | mixed_expression CALC1_T_PLUS expression           { $$ = $1 + $3; }
  | mixed_expression CALC1_T_MINUS expression          { $$ = $1 - $3; }
  | mixed_expression CALC1_T_MULTIPLY expression       { $$ = $1 * $3; }
  | mixed_expression CALC1_T_DIVIDE expression         { $$ = $1 / $3; }
  | expression CALC1_T_DIVIDE expression               { $$ = $1 / (float)$3; }
;

expression: CALC1_T_INT                                { $$ = $1; }
  | expression CALC1_T_PLUS expression                 { $$ = $1 + $3; }
  | expression CALC1_T_MINUS expression                { $$ = $1 - $3; }
  | expression CALC1_T_MULTIPLY expression             { $$ = $1 * $3; }
  | CALC1_T_LEFT expression CALC1_T_RIGHT               { $$ = $2; }
;

%%

