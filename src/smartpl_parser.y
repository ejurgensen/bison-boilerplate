/* =========================== BOILERPLATE SECTION ===========================*/

/* No global variables and yylex has scanner as argument */
%define api.pure true

/* Change prefix of symbols from yy to avoid clashes with any other parsers we
   may want to link */
%define api.prefix {smartpl_}

/* Gives better errors than "syntax error" */
%define parse.error verbose

/* Adds output parameter to the parser */
%parse-param {struct smartpl_result *result}

/* Adds "scanner" as argument to the parses calls to yylex, which is required
   when the lexer is in reentrant mode. The type is void because caller caller
   shouldn't need to know about yyscan_t */
%param {void *scanner}

/* Convenience function for caller to use instead of interfacing with lexer and
   parser directly */
%code provides {
int smartpl_lex_parse(struct smartpl_result *result, char *input);
}

/* Implementation of the convenience function and the parsing error function
   required by Bison */
%code {
  #define YYSTYPE SMARTPL_STYPE
  #include "smartpl_lexer.h"

  int smartpl_lex_parse(struct smartpl_result *result, char *input)
  {
    YY_BUFFER_STATE buffer;
    yyscan_t scanner;
    int retval = -1;
    int ret;

    result->errmsg[0] = '\0'; // For safety

    ret = smartpl_lex_init(&scanner);
    if (ret != 0)
      goto error_init;

    buffer = smartpl__scan_string(input, scanner);
    if (!buffer)
      goto error_buffer;

    ret = smartpl_parse(result, scanner);
    if (ret != 0)
      goto error_parse;

    retval = 0;

   error_parse:
    smartpl__delete_buffer(buffer, scanner);
   error_buffer:
    smartpl_lex_destroy(scanner);
   error_init:
    return retval;
  }

  void smartpl_error(struct smartpl_result *result, yyscan_t scanner, const char *msg)
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
struct smartpl_result {
  char query[512];
  char errmsg[128];
};
}

%union {
  int ival;
  char *str;
}

%token SMARTPL_T_END 0
%token SMARTPL_T_STRTAG
%token SMARTPL_T_IS
%token<ival> SMARTPL_T_INTTAG

%type<str> expr

%start conversion

%%

conversion:
  | conversion expr SMARTPL_T_END           { snprintf(result->query, sizeof(result->query), "%s", $2); }
;

expr: SMARTPL_T_STRTAG                      { $$ = "1"; }
  | expr SMARTPL_T_IS expr                  { $$ = "2"; }
;


%%

