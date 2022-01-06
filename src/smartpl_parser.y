/* =========================== BOILERPLATE SECTION ===========================*/

/* No global variables and yylex has scanner as argument */
%define api.pure true

/* Change prefix of symbols from yy to avoid clashes with any other parsers we
   may want to link */
%define api.prefix {smartpl_}

/* Gives better errors than "syntax error" */
%define parse.error verbose

/* Enables debug mode */
%define parse.trace

/* Adds output parameter to the parser */
%parse-param {struct smartpl_result *result}

/* Adds "scanner" as argument to the parses calls to yylex, which is required
   when the lexer is in reentrant mode. The type is void because caller caller
   shouldn't need to know about yyscan_t */
%param {void *scanner}

%code provides {
/* Convenience functions for caller to use instead of interfacing with lexer and
   parser directly */
int smartpl_lex_cb(char *input, void (*cb)(int, const char *));
int smartpl_lex_parse(struct smartpl_result *result, char *input);
}

/* Implementation of the convenience function and the parsing error function
   required by Bison */
%code {
  #include "smartpl_lexer.h"

  int smartpl_lex_cb(char *input, void (*cb)(int, const char *))
  {
    int ret;
    yyscan_t scanner;
    YY_BUFFER_STATE buf;
    YYSTYPE val;

    if ((ret = smartpl_lex_init(&scanner)) != 0)
      return ret;

    buf = smartpl__scan_string(input, scanner);

    while ((ret = smartpl_lex(&val, scanner)) > 0)
      cb(ret, smartpl_get_text(scanner));

    smartpl__delete_buffer(buf, scanner);
    smartpl_lex_destroy(scanner);
    return 0;
  }

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

/* ============ ABSTRACT SYNTAX TREE (AST) BOILERPLATE SECTION ===============*/

%code {
  struct ast
  {
    int type;
    struct ast *l;
    struct ast *r;
    void *data;
    int ival;
  };

  __attribute__((unused)) static struct ast * ast_new(int type, struct ast *l, struct ast *r)
  {
    struct ast *a = calloc(1, sizeof(struct ast));

    printf("Adding ast type %d\n", type);

    a->type = type;
    a->l = l;
    a->r = r;
    return a;
  }

  /* Note *data is expected to be freeable with regular free() */
  __attribute__((unused)) static struct ast * ast_data(int type, void *data)
  {
    struct ast *a = calloc(1, sizeof(struct ast));

    printf("Adding type %d, char %s\n", type, (char *)data);

    a->type = type;
    a->data = data;
    return a;
  }

  /* Note *data is expected to be freeable with regular free() */
  __attribute__((unused)) static struct ast * ast_int(int type, int ival)
  {
    struct ast *a = calloc(1, sizeof(struct ast));

    printf("Adding type %d, int %d\n", type, ival);

    a->type = type;
    a->ival = ival;
    return a;
  }

  __attribute__((unused)) static void ast_free(struct ast *a)
  {
    if (!a)
      return;

    ast_free(a->l);
    ast_free(a->r);
    free(a->data);
    free(a);
  }
}

%destructor { ast_free($$); } <ast>


/* ========================= NON-BOILERPLATE SECTION =========================*/

/* Includes required by the parser rules */
%code top {
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <time.h>
#include <assert.h>
}

/* Definition of struct that will hold the parsing result */
%code requires {
struct smartpl_result {
  char str[1024];
  int offset;
  char errmsg[128];
};
}

%code {
enum sql_append_type {
  SQL_APPEND_PLAYLIST,
  SQL_APPEND_OPERATOR,
  SQL_APPEND_OPERATOR_LIKE,
  SQL_APPEND_STR,
  SQL_APPEND_INT,
  SQL_APPEND_ORDER,
  SQL_APPEND_GROUP,
};

static void sql_from_ast(struct smartpl_result *result, struct ast *a);

static void sql_append_recursive(struct smartpl_result *result, struct ast *a, const char *op, const char *op_not, bool is_not, enum sql_append_type append_type)
{
  switch (append_type)
  {
    case SQL_APPEND_PLAYLIST:
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "playlist = \"");
      sql_from_ast(result, a->l);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "\" AND ");
      sql_from_ast(result, a->r);
      break;
    case SQL_APPEND_OPERATOR:
      sql_from_ast(result, a->l);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, " %s ", is_not ? op_not : op);
      sql_from_ast(result, a->r);
      break;
    case SQL_APPEND_OPERATOR_LIKE:
      sql_from_ast(result, a->l);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, " %s %%", is_not ? op_not : op);
      sql_from_ast(result, a->r);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "%%");
      break;
    case SQL_APPEND_STR:
      assert(a->l == NULL);
      assert(a->r == NULL);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "%s", (char *)a->data);
      break;
    case SQL_APPEND_INT:
      assert(a->l == NULL);
      assert(a->r == NULL);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "%d", a->ival);
      break;
    case SQL_APPEND_ORDER:
      assert(a->l == NULL);
      assert(a->r == NULL);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "%s %s", (char *)a->data, op);
      break;
    case SQL_APPEND_GROUP:
      assert(a->r == NULL);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "(");
      sql_from_ast(result, a->l);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, ")");
      break;
  }
}

/* Creates the parsing result from the AST */
static void sql_from_ast(struct smartpl_result *result, struct ast *a) {
  if (!a)
    return;

  bool is_not = (a->type & 0x80000000);

  a->type &= ~0x80000000;

  /* TODO Error handling, check lengths */

  switch (a->type)
  {
    case SMARTPL_T_PL:
      sql_append_recursive(result, a, NULL, NULL, 0, SQL_APPEND_PLAYLIST); break;
    case SMARTPL_T_EQUALS:
      sql_append_recursive(result, a, "=", "!=", is_not, SQL_APPEND_OPERATOR); break;
    case SMARTPL_T_LESS:
      sql_append_recursive(result, a, "<", ">=", is_not, SQL_APPEND_OPERATOR); break;
    case SMARTPL_T_LESSEQUAL:
      sql_append_recursive(result, a, "<=", ">", is_not, SQL_APPEND_OPERATOR); break;
    case SMARTPL_T_GREATER:
      sql_append_recursive(result, a, ">", ">=", is_not, SQL_APPEND_OPERATOR); break;
    case SMARTPL_T_GREATEREQUAL:
      sql_append_recursive(result, a, ">=", "<", is_not, SQL_APPEND_OPERATOR); break;
    case SMARTPL_T_IS:
      sql_append_recursive(result, a, "=", "!=", is_not, SQL_APPEND_OPERATOR); break;
    case SMARTPL_T_INCLUDES:
      sql_append_recursive(result, a, "LIKE", "NOT LIKE", is_not, SQL_APPEND_OPERATOR_LIKE); break;
    case SMARTPL_T_BEFORE:
      sql_append_recursive(result, a, "<", ">=", is_not, SQL_APPEND_OPERATOR); break;
    case SMARTPL_T_AFTER:
      sql_append_recursive(result, a, ">", "<=", is_not, SQL_APPEND_OPERATOR); break;
    case SMARTPL_T_AND:
      sql_append_recursive(result, a, "AND", "AND NOT", is_not, SQL_APPEND_OPERATOR); break;
    case SMARTPL_T_OR:
      sql_append_recursive(result, a, "OR", "OR NOT", is_not, SQL_APPEND_OPERATOR); break;
    case SMARTPL_T_ORDERBY:
      sql_append_recursive(result, a, "ORDER BY", NULL, 0, SQL_APPEND_OPERATOR); break;
    case SMARTPL_T_LIMIT:
      sql_append_recursive(result, a, "LIMIT", NULL, 0, SQL_APPEND_OPERATOR); break;
    case SMARTPL_T_QUOTED:
    case SMARTPL_T_STRTAG:
    case SMARTPL_T_INTTAG:
    case SMARTPL_T_DATETAG:
    case SMARTPL_T_DATAKINDTAG:
    case SMARTPL_T_MEDIAKINDTAG:
      sql_append_recursive(result, a, NULL, NULL, 0, SQL_APPEND_STR); break;
    case SMARTPL_T_NUM:
    case SMARTPL_T_DATAKIND:
    case SMARTPL_T_MEDIAKIND:
    case SMARTPL_T_DATE:
      sql_append_recursive(result, a, NULL, NULL, 0, SQL_APPEND_INT); break;
    case SMARTPL_T_ORDER_ASC:
      sql_append_recursive(result, a, "ASC", NULL, 0, SQL_APPEND_ORDER); break;
    case SMARTPL_T_ORDER_DESC:
      sql_append_recursive(result, a, "DESC", NULL, 0, SQL_APPEND_ORDER); break;
    case SMARTPL_T_LEFT:
      sql_append_recursive(result, a, NULL, NULL, 0, SQL_APPEND_GROUP); break;
    default:
      printf("MISSING TAG: %d\n", a->type);
  }
}
}

%union {
  unsigned int ival;
  char *str;
  struct ast *ast;
}

%token SMARTPL_T_PL

%token <str> SMARTPL_T_QUOTED

/* THe semantic value holds the actual name of the field */
%token <str> SMARTPL_T_STRTAG
%token <str> SMARTPL_T_INTTAG
%token <str> SMARTPL_T_DATETAG
%token <str> SMARTPL_T_DATAKINDTAG
%token <str> SMARTPL_T_MEDIAKINDTAG

%token SMARTPL_T_LIMIT
%token SMARTPL_T_ORDERBY
%token SMARTPL_T_ORDER_ASC
%token SMARTPL_T_ORDER_DESC
%token SMARTPL_T_RANDOM

%token SMARTPL_T_LEFT
%token SMARTPL_T_RIGHT

/* The below are only ival so we can set intbool etc via the default rule for
   semantic values, i.e. $$ = $1. The semantic value (ival) is set to the token
   value by the lexer. */
%token <ival> SMARTPL_T_EQUALS
%token <ival> SMARTPL_T_LESS
%token <ival> SMARTPL_T_LESSEQUAL
%token <ival> SMARTPL_T_GREATER
%token <ival> SMARTPL_T_GREATEREQUAL
%token <ival> SMARTPL_T_IS
%token <ival> SMARTPL_T_INCLUDES

%token <ival> SMARTPL_T_NUM
%token <ival> SMARTPL_T_DATE
%token <ival> SMARTPL_T_INTERVAL

%token <ival> SMARTPL_T_BEFORE
%token <ival> SMARTPL_T_AFTER
%token <ival> SMARTPL_T_AGO

%token <ival> SMARTPL_T_DATAKIND
%token <ival> SMARTPL_T_MEDIAKIND

%token <ival> SMARTPL_T_OR
%token <ival> SMARTPL_T_AND
%token <ival> SMARTPL_T_NOT

%left SMARTPL_T_OR SMARTPL_T_AND

%type <ast> playlist
%type <ast> expression
%type <ast> criteria
%type <ast> predicate
%type <ast> order
%type <ast> limit
%type <ival> interval
%type <ival> dateval
%type <ival> intbool
%type <ival> datebool
%type <ival> strbool
%type <ival> bool

%%

playlistlist: playlist { memset(result, 0, sizeof(struct smartpl_result)); sql_from_ast(result, $1); ast_free($1); }
;

playlist: SMARTPL_T_QUOTED '{' expression '}'      { $$ = ast_new(SMARTPL_T_PL, ast_data(SMARTPL_T_QUOTED, $1), $3); }
;

expression: criteria
| criteria order limit { $$ = ast_new(SMARTPL_T_ORDERBY, $1, ast_new(SMARTPL_T_LIMIT, $2, $3)); };
| criteria limit order { $$ = ast_new(SMARTPL_T_ORDERBY, $1, ast_new(SMARTPL_T_LIMIT, $3, $2)); };
| criteria order { $$ = ast_new(SMARTPL_T_ORDERBY, $1, $2); }
| criteria limit { $$ = ast_new(SMARTPL_T_LIMIT, $1, $2); }
;

criteria: criteria SMARTPL_T_AND criteria  { $$ = ast_new($2, $1, $3); }
| criteria SMARTPL_T_OR criteria           { $$ = ast_new($2, $1, $3); }
| SMARTPL_T_LEFT criteria SMARTPL_T_RIGHT  { $$ = ast_new(SMARTPL_T_LEFT, $2, NULL); }
| predicate
;

predicate: SMARTPL_T_STRTAG strbool SMARTPL_T_QUOTED { $$ = ast_new($2, ast_data(SMARTPL_T_STRTAG, $1), ast_data(SMARTPL_T_QUOTED, $3)); }
| SMARTPL_T_INTTAG intbool SMARTPL_T_NUM          { $$ = ast_new($2, ast_data(SMARTPL_T_INTTAG, $1), ast_int(SMARTPL_T_NUM, $3)); }
| SMARTPL_T_DATETAG datebool dateval              { $$ = ast_new($2, ast_data(SMARTPL_T_DATETAG, $1), ast_int(SMARTPL_T_DATE, $3)); }
| SMARTPL_T_DATAKINDTAG bool SMARTPL_T_DATAKIND { $$ = ast_new($2, ast_data(SMARTPL_T_DATAKINDTAG, $1), ast_int(SMARTPL_T_DATAKIND, $3)); }
| SMARTPL_T_MEDIAKINDTAG bool SMARTPL_T_MEDIAKIND { $$ = ast_new($2, ast_data(SMARTPL_T_MEDIAKINDTAG, $1), ast_int(SMARTPL_T_MEDIAKIND, $3)); }
| SMARTPL_T_NOT predicate                         { struct ast *a = $2; a->type |= 0x80000000; $$ = $2; }
;

strbool: bool
| SMARTPL_T_INCLUDES
;

bool: SMARTPL_T_IS
;

intbool: SMARTPL_T_EQUALS
| SMARTPL_T_LESS
| SMARTPL_T_LESSEQUAL
| SMARTPL_T_GREATER
| SMARTPL_T_GREATEREQUAL
;

datebool: SMARTPL_T_BEFORE
| SMARTPL_T_AFTER
;

interval: SMARTPL_T_INTERVAL
| SMARTPL_T_NUM SMARTPL_T_INTERVAL { $$ = $1 * $2; }
;

dateval: SMARTPL_T_DATE
| interval SMARTPL_T_BEFORE dateval { $$ = $3 - $1; }
| interval SMARTPL_T_AFTER dateval  { $$ = $3 + $1; }
| interval SMARTPL_T_AGO            { $$ = time(NULL) - $1; }
;

order: SMARTPL_T_ORDERBY SMARTPL_T_STRTAG { $$ = ast_data(SMARTPL_T_ORDER_ASC, $2); }
| SMARTPL_T_ORDERBY SMARTPL_T_INTTAG { $$ = ast_data(SMARTPL_T_ORDER_ASC, $2); }
| SMARTPL_T_ORDERBY SMARTPL_T_DATETAG { $$ = ast_data(SMARTPL_T_ORDER_ASC, $2); }
| SMARTPL_T_ORDERBY SMARTPL_T_DATAKINDTAG { $$ = ast_data(SMARTPL_T_ORDER_ASC, $2); }
| SMARTPL_T_ORDERBY SMARTPL_T_MEDIAKINDTAG { $$ = ast_data(SMARTPL_T_ORDER_ASC, $2); }
| order SMARTPL_T_ORDER_ASC { struct ast *a = $1; a->type = SMARTPL_T_ORDER_ASC; $$ = $1; }
| order SMARTPL_T_ORDER_DESC { struct ast *a = $1; a->type = SMARTPL_T_ORDER_DESC; $$ = $1; }
;

limit: SMARTPL_T_LIMIT SMARTPL_T_NUM { $$ = ast_int(SMARTPL_T_NUM, $2); }
;

%%

