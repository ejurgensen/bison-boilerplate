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

%code provides {
/* Convenience functions for caller to use instead of interfacing with lexer and
   parser directly */
int daap_lex_cb(char *input, void (*cb)(int, const char *));
int daap_lex_parse(struct daap_result *result, char *input);
}

/* Implementation of the convenience function and the parsing error function
   required by Bison */
%code {
  #include "daap_lexer.h"

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
    void *data;
  };

  static struct ast * ast_new(int type, struct ast *l, struct ast *r)
  {
    struct ast *a = calloc(1, sizeof(struct ast));

    a->type = type;
    a->l = l;
    a->r = r;
    return a;
  }

  /* Note *data is expected to be freeable with regular free() */
  static struct ast * ast_data(int type, void *data)
  {
    struct ast *a = calloc(1, sizeof(struct ast));

    a->type = type;
    a->data = data;
    return a;
  }

  static void free_ast(struct ast *a)
  {
    if (!a)
      return;

    free_ast(a->l);
    free_ast(a->r);
    free(a->data);
    free(a);
  }
}

%destructor { free_ast($$); } <ast>


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

%code {
static char * dmap_map(char *tag)
{
  return "dummytag";
}

/* Creates the parsing result from the AST */
static void sql_from_ast(struct daap_result *result, struct ast *a) {
  if (!a)
    return;

  /* TODO Error handling, check lengths */

  switch (a->type)
    {
      case DAAP_T_OR:
      case DAAP_T_AND:
        sql_from_ast(result, a->l);
        result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, a->type == DAAP_T_OR ? " OR " : " AND ");
        sql_from_ast(result, a->r);
        break;
      case DAAP_T_KEY:
        result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "%s", dmap_map((char *)a->data));
        break;
      case DAAP_T_VALUE:
        result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "%s", a->data ? (char *)a->data : "\"\"");
        break;
      case DAAP_T_EQUAL:
      case DAAP_T_NOT:
        sql_from_ast(result, a->l);
        result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, a->type == DAAP_T_EQUAL ? " = " : " != ");
        sql_from_ast(result, a->r);
        break;
      case DAAP_T_LEFT:
        result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "(");
        sql_from_ast(result, a->l);
        result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, ")");
        break;
      default:
        printf("ERROR: %d", a->type);
  }
}
}

%union {
  char *str;
  struct ast *ast;
}

%token DAAP_T_END 0
%token<str> DAAP_T_KEY DAAP_T_VALUE
%token DAAP_T_EQUAL DAAP_T_NOT DAAP_T_QUOTE DAAP_T_LEFT DAAP_T_RIGHT DAAP_T_NEWLINE
%left DAAP_T_AND DAAP_T_OR

%type <ast> expr

%%

query:
    expr DAAP_T_END                { printf("FINAL\n"); memset(result, 0, sizeof(struct daap_result)); sql_from_ast(result, $1); free_ast($1); }
  | expr DAAP_T_NEWLINE DAAP_T_END { printf("FINAL\n"); memset(result, 0, sizeof(struct daap_result)); sql_from_ast(result, $1); free_ast($1); }
  ;

expr:
    expr DAAP_T_AND expr           { printf("AND "); $$ = ast_new(DAAP_T_AND, $1, $3); }
  | expr DAAP_T_OR expr            { printf("OR "); $$ = ast_new(DAAP_T_OR, $1, $3); }
  | DAAP_T_LEFT expr DAAP_T_RIGHT  { printf("GROUP "); $$ = ast_new(DAAP_T_LEFT, $2, NULL); }
;

expr:
    DAAP_T_QUOTE DAAP_T_KEY DAAP_T_EQUAL DAAP_T_VALUE DAAP_T_QUOTE { printf("CRIT %s = %s ", $2, $4); $$ = ast_new(DAAP_T_EQUAL, ast_data(DAAP_T_KEY, $2), ast_data(DAAP_T_VALUE, $4)); }
  | DAAP_T_QUOTE DAAP_T_KEY DAAP_T_NOT DAAP_T_VALUE DAAP_T_QUOTE   { printf("CRIT %s != %s ", $2, $4); $$ = ast_new(DAAP_T_NOT, ast_data(DAAP_T_KEY, $2), ast_data(DAAP_T_VALUE, $4)); }
  | DAAP_T_QUOTE DAAP_T_KEY DAAP_T_NOT DAAP_T_QUOTE                { printf("CRIT %s != * ", $2); $$ = ast_new(DAAP_T_NOT, ast_data(DAAP_T_KEY, $2), ast_data(DAAP_T_VALUE, NULL)); }
;

%%

