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

/* ============ ABSTRACT SYNTAX TREE (AST) BOILERPLATE SECTION ===============*/

%code {
  struct ast
  {
    int type;
    struct ast *l;
    struct ast *r;

    char *key;
    char *val;
  };

  static struct ast * new_ast(int type, struct ast *l, struct ast *r)
  {
    struct ast *a = calloc(1, sizeof(struct ast));

    a->type = type;
    a->l = l;
    a->r = r;

    return a;
  }

  static struct ast * new_crit(int type, char *key, char *val)
  {
    struct ast *a = calloc(1, sizeof(struct ast));

    a->type = type;
    a->key = key;
    a->val = val;

    return a;
  }

  static void eval_ast(struct daap_result *result, struct ast *a)
  {
    switch(a->type)
    {
      case DAAP_T_OR:
      case DAAP_T_AND:
        eval_ast(result, a->l);
        result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, a->type == DAAP_T_OR ? " OR " : " AND ");
        eval_ast(result, a->r);
        break;
      case DAAP_T_LEFT:
        result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "(");
        eval_ast(result, a->l);
        result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, ")");
        break;
      case DAAP_T_EQUAL:
        result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "%s = %s", a->key, a->val);
        break;
      case DAAP_T_NOT_EQUAL:
        result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "%s != %s", a->key, a->val ? a->val : "\"\"");
        break;
      default:
        printf("ERROR: %d", a->type);
    }
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
  int offset;
  char errmsg[128];
};
}

%union {
  char *str;
  struct ast *ast;
}

%token DAAP_T_END 0
%token<str> DAAP_T_KEY DAAP_T_VALUE
%token DAAP_T_EQUAL DAAP_T_NOT_EQUAL DAAP_T_QUOTE DAAP_T_LEFT DAAP_T_RIGHT DAAP_T_NEWLINE
%left DAAP_T_AND DAAP_T_OR

%type <ast> expr

%%

query:
    expr DAAP_T_END                { printf("FINAL\n"); memset(result, 0, sizeof(struct daap_result)); eval_ast(result, $1); }
  | expr DAAP_T_NEWLINE DAAP_T_END { printf("FINAL\n"); memset(result, 0, sizeof(struct daap_result)); eval_ast(result, $1); }
  ;

expr:
    expr DAAP_T_AND expr           { printf("AND "); $$ = new_ast(DAAP_T_AND, $1, $3); }
  | expr DAAP_T_OR expr            { printf("OR "); $$ = new_ast(DAAP_T_OR, $1, $3); }
  | DAAP_T_LEFT expr DAAP_T_RIGHT  { printf("GROUP "); $$ = new_ast(DAAP_T_LEFT, $2, NULL); }
;

expr:
    DAAP_T_QUOTE DAAP_T_KEY DAAP_T_EQUAL DAAP_T_VALUE DAAP_T_QUOTE     { printf("CRIT %s = %s ", $2, $4); $$ = new_crit(DAAP_T_EQUAL, $2, $4); }
  | DAAP_T_QUOTE DAAP_T_KEY DAAP_T_NOT_EQUAL DAAP_T_VALUE DAAP_T_QUOTE { printf("CRIT %s != %s ", $2, $4); $$ = new_crit(DAAP_T_NOT_EQUAL, $2, $4); }
  | DAAP_T_QUOTE DAAP_T_KEY DAAP_T_NOT_EQUAL DAAP_T_QUOTE              { printf("CRIT %s != * ", $2); $$ = new_crit(DAAP_T_NOT_EQUAL, $2, NULL); }
;

%%

