/* =========================== BOILERPLATE SECTION ===========================*/

/* No global variables and yylex has scanner as argument */
%define api.pure true

/* Change prefix of symbols from yy to avoid clashes with any other parsers we
   may want to link */
%define api.prefix {daap_}

/* Gives better errors than "syntax error" */
%define parse.error verbose

/* Enables debug mode */
%define parse.trace

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
  char str[1024];
  int ival;
  float fval;
  char errmsg[128];
};
}

%union {
  int ival;
  char *str;
}

%token DAAP_T_END 0
%token<ival> DAAP_T_INT
%token<str> DAAP_T_KEY DAAP_T_VALUE
%token DAAP_T_QUOTE DAAP_T_AND DAAP_T_OR DAAP_T_LEFT DAAP_T_RIGHT DAAP_T_NEWLINE
%token DAAP_T_EQUAL DAAP_T_NOT_EQUAL

%type<str> expr

%destructor { free($$); } <str>

%%

query:  expr DAAP_T_NEWLINE DAAP_T_END  { printf("Adding top level %s\n", $1); /* Add expr to AST */ }
  |     expr DAAP_T_END                 { printf("Adding top level %s\n", $1); /* Add expr to AST */ }
  ;

expr:
        DAAP_T_QUOTE DAAP_T_KEY DAAP_T_QUOTE { printf("Found %s\n", $2); $$ = $2; }
;

%%

