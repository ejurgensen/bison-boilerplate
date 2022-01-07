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
#define _GNU_SOURCE // For asprintf
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <time.h>
#include <assert.h>

#define INVERT_MASK 0x80000000
}

/* Definition of struct that will hold the parsing result */
%code requires {
struct result_part {
  char str[512];
  int offset;
};

struct smartpl_result {
  struct result_part where_part;
  struct result_part order_part;
  struct result_part having_part;
  char title[128];
  const char *where; // Points to where_part.str
  const char *order; // Points to order_part.str
  const char *having; // Points to having_part.str
  int limit;
  char errmsg[128];
};
}

%code {
enum sql_append_type {
  SQL_APPEND_OPERATOR,
  SQL_APPEND_OPERATOR_STR,
  SQL_APPEND_OPERATOR_LIKE,
  SQL_APPEND_FIELD,
  SQL_APPEND_STR,
  SQL_APPEND_INT,
  SQL_APPEND_ORDER,
  SQL_APPEND_GROUP,
  SQL_APPEND_DATE_STRFTIME,
  SQL_APPEND_DATE_FIELD,
};

static const char * sql_from_ast(struct result_part *result, struct ast *a);

static void sql_append_recursive(struct result_part *result, struct ast *a, const char *op, const char *op_not, bool is_not, enum sql_append_type append_type)
{
  switch (append_type)
  {
    case SQL_APPEND_OPERATOR:
      sql_from_ast(result, a->l);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, " %s ", is_not ? op_not : op);
      sql_from_ast(result, a->r);
      break;
    case SQL_APPEND_OPERATOR_STR:
      sql_from_ast(result, a->l);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, " %s '", is_not ? op_not : op);
      sql_from_ast(result, a->r);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "'");
      break;
    case SQL_APPEND_OPERATOR_LIKE:
      sql_from_ast(result, a->l);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, " %s '%%", is_not ? op_not : op);
      sql_from_ast(result, a->r);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "%%'");
      break;
    case SQL_APPEND_FIELD:
      assert(a->l == NULL);
      assert(a->r == NULL);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "f.%s", (char *)a->data);
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
      if (a->data)
        result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "f.%s ", (char *)a->data);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "%s", is_not ? op_not : op);
      break;
    case SQL_APPEND_GROUP:
      assert(a->r == NULL);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "(");
      sql_from_ast(result, a->l);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, ")");
      break;
    case SQL_APPEND_DATE_STRFTIME:
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "strftime('%%s', datetime(");
      sql_from_ast(result, a->l); // Appends the anchor date
      sql_from_ast(result, a->r); // Appends interval if there is one
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "'utc'))");
      break;
    case SQL_APPEND_DATE_FIELD:
      assert(a->l == NULL);
      assert(a->r == NULL);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "'");
      if (is_not ? op_not : op)
        result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "%s", is_not ? op_not : op);
      if (a->data)
        result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "%s", (char *)a->data);
      result->offset += snprintf(result->str + result->offset, sizeof(result->str) - result->offset, "', ");
      break;
  }
}

/* Creates the parsing result from the AST */
static const char * sql_from_ast(struct result_part *result, struct ast *a) {
  if (!a)
    return NULL;

  bool is_not = (a->type & INVERT_MASK);

  a->type &= ~INVERT_MASK;

  /* TODO Error handling, check lengths */

  switch (a->type)
  {
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
      sql_append_recursive(result, a, "=", "!=", is_not, SQL_APPEND_OPERATOR_STR); break;
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
    case SMARTPL_T_DATEEXPR:
      sql_append_recursive(result, a, NULL, NULL, 0, SQL_APPEND_DATE_STRFTIME); break; // 2004-01-01 -> datetime('2004-01-01', 'utc')
    case SMARTPL_T_DATE:
      sql_append_recursive(result, a, NULL, NULL, 0, SQL_APPEND_DATE_FIELD); break;
    case SMARTPL_T_DATE_TODAY:
      sql_append_recursive(result, a, "now', 'start of day", NULL, 0, SQL_APPEND_DATE_FIELD); break;
    case SMARTPL_T_DATE_YESTERDAY:
      sql_append_recursive(result, a, "now', 'start of day', '-1 day", NULL, 0, SQL_APPEND_DATE_FIELD); break;
    case SMARTPL_T_DATE_LASTWEEK:
      sql_append_recursive(result, a, "now', 'start of day', 'weekday 0', '-13 days", NULL, 0, SQL_APPEND_DATE_FIELD); break;
    case SMARTPL_T_DATE_LASTMONTH:
      sql_append_recursive(result, a, "now', 'start of month', '-1 month", NULL, 0, SQL_APPEND_DATE_FIELD); break;
    case SMARTPL_T_DATE_LASTYEAR:
      sql_append_recursive(result, a, "now', 'start of year', '-1 year", NULL, 0, SQL_APPEND_DATE_FIELD); break;
    // 2 weeks after today -> datetime('now', 'start of day', '+14 days', 'utc')
    // 2 weeks ago -> datetime('now', 'start of day', '-14 days', 'utc')
    // 2 weeks before 2004-01-01 -> datetime('2004-01-01', '-14 days', 'utc')
    case SMARTPL_T_INTERVAL:
      sql_append_recursive(result, a, "-", "+", is_not, SQL_APPEND_DATE_FIELD); break;
    case SMARTPL_T_UNQUOTED:
    case SMARTPL_T_GROUPTAG:
      sql_append_recursive(result, a, NULL, NULL, 0, SQL_APPEND_STR); break;
    case SMARTPL_T_STRTAG:
    case SMARTPL_T_INTTAG:
    case SMARTPL_T_DATETAG:
    case SMARTPL_T_DATAKINDTAG:
    case SMARTPL_T_MEDIAKINDTAG:
      sql_append_recursive(result, a, NULL, NULL, 0, SQL_APPEND_FIELD); break;
    case SMARTPL_T_NUM:
    case SMARTPL_T_DATAKIND:
    case SMARTPL_T_MEDIAKIND:
      sql_append_recursive(result, a, NULL, NULL, 0, SQL_APPEND_INT); break;
    case SMARTPL_T_ORDERBY:
      sql_append_recursive(result, a, "ASC", "DESC", is_not, SQL_APPEND_ORDER); break;
    case SMARTPL_T_RANDOM:
      sql_append_recursive(result, a, "random()", NULL, 0, SQL_APPEND_ORDER); break;
    case SMARTPL_T_LEFT:
      sql_append_recursive(result, a, NULL, NULL, 0, SQL_APPEND_GROUP); break;
    default:
      printf("MISSING TAG: %d\n", a->type);
  }

  return result->str;
}

static void result_set(struct smartpl_result *result, char *title, struct ast *criteria, struct ast *having, struct ast *order, struct ast *limit)
{
  memset(result, 0, sizeof(struct smartpl_result));
  snprintf(result->title, sizeof(result->title), "%s", title);
  result->where  = sql_from_ast(&result->where_part, criteria);
  result->having = sql_from_ast(&result->having_part, having);
  result->order  = sql_from_ast(&result->order_part, order);
  result->limit  = limit ? limit->ival : 0;

  free(title);
  ast_free(criteria);
  ast_free(having);
  ast_free(order);
}
}

%union {
  unsigned int ival;
  char *str;
  struct ast *ast;
}

/* A string that was quoted. Quotes were stripped by lexer. */
%token <str> SMARTPL_T_UNQUOTED

/* The semantic value holds the actual name of the field */
%token <str> SMARTPL_T_STRTAG
%token <str> SMARTPL_T_INTTAG
%token <str> SMARTPL_T_DATETAG
%token <str> SMARTPL_T_DATAKINDTAG
%token <str> SMARTPL_T_MEDIAKINDTAG
%token <str> SMARTPL_T_GROUPTAG

%token SMARTPL_T_DATEEXPR
%token SMARTPL_T_HAVING
%token SMARTPL_T_ORDERBY
%token SMARTPL_T_ORDER_ASC
%token SMARTPL_T_ORDER_DESC
%token SMARTPL_T_LIMIT
%token SMARTPL_T_RANDOM
%token SMARTPL_T_LEFT
%token SMARTPL_T_RIGHT
%token SMARTPL_T_OR
%token SMARTPL_T_AND
%token SMARTPL_T_NOT

%token SMARTPL_T_DAYS
%token SMARTPL_T_WEEKS
%token SMARTPL_T_MONTHS
%token SMARTPL_T_YEARS
%token SMARTPL_T_INTERVAL

%token <str> SMARTPL_T_DATE
%token <ival> SMARTPL_T_DATE_TODAY
%token <ival> SMARTPL_T_DATE_YESTERDAY
%token <ival> SMARTPL_T_DATE_LASTWEEK
%token <ival> SMARTPL_T_DATE_LASTMONTH
%token <ival> SMARTPL_T_DATE_LASTYEAR

%token <ival> SMARTPL_T_NUM
%token <ival> SMARTPL_T_DATAKIND
%token <ival> SMARTPL_T_MEDIAKIND

/* The below are only ival so we can set intbool, datebool and strbool via the
   default rule for semantic values, i.e. $$ = $1. The semantic value (ival) is
   set to the token value by the lexer. */
%token <ival> SMARTPL_T_EQUALS
%token <ival> SMARTPL_T_LESS
%token <ival> SMARTPL_T_LESSEQUAL
%token <ival> SMARTPL_T_GREATER
%token <ival> SMARTPL_T_GREATEREQUAL
%token <ival> SMARTPL_T_IS
%token <ival> SMARTPL_T_INCLUDES
%token <ival> SMARTPL_T_BEFORE
%token <ival> SMARTPL_T_AFTER
%token <ival> SMARTPL_T_AGO

%left SMARTPL_T_OR SMARTPL_T_AND

%type <ast> criteria
%type <ast> predicate
%type <ast> dateexpr
%type <ast> interval
%type <ast> having
%type <ast> order
%type <ast> limit
%type <str> time
%type <ival> daterelative
%type <ival> strbool
%type <ival> intbool
%type <ival> datebool

%%

playlist:
  SMARTPL_T_UNQUOTED '{' criteria having order limit '}'    { result_set(result, $1, $3, $4, $5, $6); }
| SMARTPL_T_UNQUOTED '{' criteria having order '}'          { result_set(result, $1, $3, $4, $5, NULL); }
| SMARTPL_T_UNQUOTED '{' criteria having limit '}'          { result_set(result, $1, $3, $4, NULL, $5); }
| SMARTPL_T_UNQUOTED '{' criteria having '}'                { result_set(result, $1, $3, $4, NULL, NULL); }
| SMARTPL_T_UNQUOTED '{' criteria order limit '}'           { result_set(result, $1, $3, NULL, $4, $5); }
| SMARTPL_T_UNQUOTED '{' criteria order '}'                 { result_set(result, $1, $3, NULL, $4, NULL); }
| SMARTPL_T_UNQUOTED '{' criteria limit '}'                 { result_set(result, $1, $3, NULL, NULL, $4); }
| SMARTPL_T_UNQUOTED '{' criteria '}'                       { result_set(result, $1, $3, NULL, NULL, NULL); }
;

criteria: criteria SMARTPL_T_AND criteria                   { $$ = ast_new(SMARTPL_T_AND, $1, $3); }
| criteria SMARTPL_T_OR criteria                            { $$ = ast_new(SMARTPL_T_OR, $1, $3); }
| SMARTPL_T_LEFT criteria SMARTPL_T_RIGHT                   { $$ = ast_new(SMARTPL_T_LEFT, $2, NULL); }
| predicate
;

predicate: SMARTPL_T_STRTAG strbool SMARTPL_T_UNQUOTED      { $$ = ast_new($2, ast_data(SMARTPL_T_STRTAG, $1), ast_data(SMARTPL_T_UNQUOTED, $3)); }
| SMARTPL_T_INTTAG intbool SMARTPL_T_NUM                    { $$ = ast_new($2, ast_data(SMARTPL_T_INTTAG, $1), ast_int(SMARTPL_T_NUM, $3)); }
| SMARTPL_T_DATETAG datebool dateexpr                       { $$ = ast_new($2, ast_data(SMARTPL_T_DATETAG, $1), $3); }
| SMARTPL_T_DATAKINDTAG SMARTPL_T_IS SMARTPL_T_DATAKIND     { $$ = ast_new(SMARTPL_T_EQUALS, ast_data(SMARTPL_T_DATAKINDTAG, $1), ast_int(SMARTPL_T_DATAKIND, $3)); }
| SMARTPL_T_MEDIAKINDTAG SMARTPL_T_IS SMARTPL_T_MEDIAKIND   { $$ = ast_new(SMARTPL_T_EQUALS, ast_data(SMARTPL_T_MEDIAKINDTAG, $1), ast_int(SMARTPL_T_MEDIAKIND, $3)); }
| SMARTPL_T_NOT predicate                                   { struct ast *a = $2; a->type |= INVERT_MASK; $$ = $2; }
;

dateexpr: SMARTPL_T_DATE                                    { $$ = ast_new(SMARTPL_T_DATEEXPR, ast_data(SMARTPL_T_DATE, $1), NULL); }
| daterelative                                              { $$ = ast_new(SMARTPL_T_DATEEXPR, ast_data($1, NULL), NULL); }
| interval SMARTPL_T_DATE                                   { $$ = ast_new(SMARTPL_T_DATEEXPR, ast_data(SMARTPL_T_DATE, $2), $1); }
| interval daterelative                                     { $$ = ast_new(SMARTPL_T_DATEEXPR, ast_data($2, NULL), $1); }
| time SMARTPL_T_AGO                                        { $$ = ast_new(SMARTPL_T_DATEEXPR, ast_data(SMARTPL_T_DATE_TODAY, NULL), ast_data(SMARTPL_T_INTERVAL, $1)); }

daterelative: SMARTPL_T_DATE_TODAY
| SMARTPL_T_DATE_YESTERDAY
| SMARTPL_T_DATE_LASTWEEK
| SMARTPL_T_DATE_LASTMONTH
| SMARTPL_T_DATE_LASTYEAR
;

interval: time SMARTPL_T_BEFORE                             { $$ = ast_data(SMARTPL_T_INTERVAL, $1); }
| time SMARTPL_T_AFTER                                      { $$ = ast_data(SMARTPL_T_INTERVAL | INVERT_MASK, $1); }
;

time: SMARTPL_T_NUM SMARTPL_T_DAYS                          { if (asprintf(&($$), "%d days", $1) < 0) YYABORT; }
| SMARTPL_T_NUM SMARTPL_T_WEEKS                             { if (asprintf(&($$), "%d days", 7 * $1) < 0) YYABORT; }
| SMARTPL_T_NUM SMARTPL_T_MONTHS                            { if (asprintf(&($$), "%d months", $1) < 0) YYABORT;  }
| SMARTPL_T_NUM SMARTPL_T_YEARS                             { if (asprintf(&($$), "%d years", $1) < 0) YYABORT;  }
;

having: SMARTPL_T_HAVING SMARTPL_T_GROUPTAG intbool SMARTPL_T_NUM { $$ = ast_new($3, ast_data(SMARTPL_T_GROUPTAG, $2), ast_int(SMARTPL_T_NUM, $4)); }

order: SMARTPL_T_ORDERBY SMARTPL_T_STRTAG                   { $$ = ast_data(SMARTPL_T_ORDERBY, $2); }
| SMARTPL_T_ORDERBY SMARTPL_T_INTTAG                        { $$ = ast_data(SMARTPL_T_ORDERBY, $2); }
| SMARTPL_T_ORDERBY SMARTPL_T_DATETAG                       { $$ = ast_data(SMARTPL_T_ORDERBY, $2); }
| SMARTPL_T_ORDERBY SMARTPL_T_DATAKINDTAG                   { $$ = ast_data(SMARTPL_T_ORDERBY, $2); }
| SMARTPL_T_ORDERBY SMARTPL_T_MEDIAKINDTAG                  { $$ = ast_data(SMARTPL_T_ORDERBY, $2); }
| SMARTPL_T_ORDERBY SMARTPL_T_RANDOM                        { $$ = ast_data(SMARTPL_T_RANDOM, NULL); }
| order SMARTPL_T_ORDER_ASC                                 { struct ast *a = $1; a->type = SMARTPL_T_ORDERBY; $$ = $1; }
| order SMARTPL_T_ORDER_DESC                                { struct ast *a = $1; a->type |= INVERT_MASK; $$ = $1; }
;

limit: SMARTPL_T_LIMIT SMARTPL_T_NUM                        { $$ = ast_int(SMARTPL_T_LIMIT, $2); }
;

strbool: SMARTPL_T_IS
| SMARTPL_T_INCLUDES
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

%%

