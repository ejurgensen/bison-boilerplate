#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "daap_parser.h"
#include "smartpl_parser.h"

#define DEBUG_SHOW_LEX 0

struct test_query
{
  char *input;
  char *expected;
};

static struct test_query smartpl_test_queries[] =
{
  {
    "\"tech1\" { genre includes \"techno\" and not artist includes \"zombie\" and album is \"test\" }",
    "tech1: WHERE f.genre LIKE '%techno%' AND f.artist NOT LIKE '%zombie%' AND f.album = 'test'"
  },
  {
    "\"techno 2015\" {\ngenre includes \"techno\"\n and artist includes \"zombie\"\nand not genre includes \"industrial\"\n}\n",
    "techno 2015: WHERE f.genre LIKE '%techno%' AND f.artist LIKE '%zombie%' AND f.genre NOT LIKE '%industrial%'"
  },
  {
    "\"Local music\" {data_kind is spotify and media_kind is music}",
    "Local music: WHERE f.data_kind = 2 AND f.media_kind = 0"
  },
  {
    "\"Unplayed podcasts and audiobooks\" { play_count = 0 and (media_kind is podcast or media_kind is audiobook) }",
    "Unplayed podcasts and audiobooks: WHERE f.play_count = 0 AND (f.media_kind = 2 OR f.media_kind = 3)"
  },
  {
    "\"Recently added music\" { media_kind is music order by time_added desc limit 10 }",
    "Recently added music: WHERE f.media_kind = 0 ORDER BY f.time_added DESC LIMIT 10"
  },
  {
    "\"Recently added music\" { media_kind is music limit 20 order by time_added desc }",
    "[invalid syntax]"
  },
  {
    "\"Random 10 Rated Pop songs\" { rating > 0 and  genre is \"Pop\" and media_kind is music  order by random desc limit 10 }",
    "Random 10 Rated Pop songs: WHERE f.rating > 0 AND f.genre = 'Pop' AND f.media_kind = 0 ORDER BY random() LIMIT 10"
  },
  {
    "\"Files added after January 1, 2004\" { time_added after 2004-01-01 }",
    "Files added after January 1, 2004: WHERE f.time_added > strftime('%s', datetime('2004-01-01', 'utc'))"
  },
  {
    "\"Recently Added\" { time_added after 2 weeks ago }",
    "Recently Added: WHERE f.time_added > strftime('%s', datetime('now', 'start of day', '-14 days', 'utc'))"
  },
  {
    "\"Recently played audiobooks\" { time_played after last week and media_kind is audiobook }",
    "Recently played audiobooks: WHERE f.time_played > strftime('%s', datetime('now', 'start of day', 'weekday 0', '-13 days', 'utc')) AND f.media_kind = 3"
  },
  {
    "\"query\" { time_added after 8 weeks ago and media_kind is music having track_count > 3 order by time_added desc }",
    "query: WHERE f.time_added > strftime('%s', datetime('now', 'start of day', '-56 days', 'utc')) AND f.media_kind = 0 HAVING track_count > 3 ORDER BY f.time_added DESC"
  },
};


// ('daap.songartist!:') -> 1 = 1
static struct test_query daap_test_queries[] =
{
  {
    "('daap.teststr!:')",
    "((f.teststr <> '' AND f.teststr IS NOT NULL))"
  },
  {
    "('daap.teststr:')",
    "((f.teststr = '' OR f.teststr IS NULL))"
  },
  {
    "('daap.songartist!:' 'daap.testint:1')",
    "((1 = 1) AND f.testint = 1)"
  },
  {
    "('daap.songartist!:','daap.testint:1')",
    "((1 = 1) OR f.testint = 1)"
  },
  {
    "('daap.songartist!:' ('daap.testint:1','com.apple.itunes.extended-media-kind:32'))",
    "((1 = 1) AND (f.testint = 1 OR (1 = 0)))"
  },
  {
    "(('com.apple.itunes.mediakind:1','com.apple.itunes.mediakind:32') 'daap.songartist!:')",
    "((f.testint = 1 OR (1 = 0)) AND (1 = 1))"
  },
  {
    "('daap.songalbumid:0')",
    "((1 = 1))"
  },
  {
    "('daap.songalbumid!:0')",
    "(f.testint <> 0)"
  },

  {
    "('daap.songalbumid:1034227734086706124' ('com.apple.itunes.extended-media-kind:4','com.apple.itunes.extended-media-kind:36','com.apple.itunes.extended-media-kind:6','com.apple.itunes.extended-media-kind:7'))",
    "(f.testint = 1034227734086706124 AND (f.testint = 4 OR f.testint = 36 OR f.testint = 6 OR f.testint = 7))"
  },
  {
    "('daap.songartistid:6912769229437698119' ('com.apple.itunes.extended-media-kind:1','com.apple.itunes.extended-media-kind:32'))",
    "(f.testint = 6912769229437698119 AND (f.testint = 1 OR (1 = 0)))"
  },

  {
    "('com.apple.itunes.playlist-contains-media-type:1','com.apple.itunes.playlist-contains-media-type:32','com.apple.itunes.playlist-contains-media-type:128','com.apple.itunes.playlist-contains-media-type:1024','com.apple.itunes.playlist-contains-media-type:65537')",
    "(f.testint = 1 OR f.testint = 32 OR f.testint = 128 OR f.testint = 1024 OR f.testint = 65537)"
  },
  {
    "('daap.teststr:My Music on thundarr','com.apple.itunes.extended-media-kind@1','com.apple.itunes.extended-media-kind@32','com.apple.itunes.extended-media-kind@128','com.apple.itunes.extended-media-kind@65537')",
    "(f.teststr = 'My Music on thundarr' OR f.testint = 1 OR (1 = 0) OR f.testint = 128 OR f.testint = 65537)"
  },
  {
    "'daap.teststr:Kid\\'s Audiobooks'", // dmap.itemname
    "f.teststr = 'KidXXs Audiobooks'" // Should really become "f.teststr = 'Kid''s Audiobooks'"
  },
  {
    "'daap.teststr:RadioBla'", // dmap.itemname
    "f.teststr = 'RadioBla'"
  },
  {
    "('daap.teststr:*cfbnk*' ('com.apple.itunes.mediakind:1','com.apple.itunes.mediakind:32') 'daap.songartist!:')",
    "(f.teststr LIKE '%cfbnk%' AND (f.testint = 1 OR (1 = 0)) AND (1 = 1))"
  },
  {
    "(('com.apple.itunes.mediakind:4','com.apple.itunes.mediakind:36','com.apple.itunes.mediakind:6','com.apple.itunes.mediakind:7') 'daap.songalbumid:1034227734086706124')",
    "((f.testint = 4 OR f.testint = 36 OR f.testint = 6 OR f.testint = 7) AND f.testint = 1034227734086706124)"
  },
  {
    "('daap.teststr:*Radio%B_la*2*')", // dmap.itemname
    "(f.teststr LIKE '%Radio\\%B\\_la*2%') ESCAPE '\\'"
  },
  {
    "('daap.teststr!:*Radio%Bla*2*')", // dmap.itemname
    "(f.teststr NOT LIKE '%Radio\\%Bla*2%') ESCAPE '\\'"
  },
};

#if DEBUG_SHOW_LEX
static void
print_token_cb(int token, const char *s)
{
  printf("Token %d: %s\n", token, s);
}

static void
daap_test_lexer(char *input, char *expected)
{
  printf("Lexing %s\n", input);
  daap_lex_cb(input, print_token_cb);
  printf("Done lexing\n\n");
}

static void
smartpl_test_lexer(char *input, char *expected)
{
  printf("Lexing %s\n", input);
  smartpl_lex_cb(input, print_token_cb);
  printf("Done lexing\n\n");
}
#else
static void
daap_test_lexer(char *input, char *expected)
{
  return;
}

static void
smartpl_test_lexer(char *input, char *expected)
{
  return;
}
#endif

static void
daap_test_parse(int n, char *input, char *expected)
{
  struct daap_result result;

  printf("=== INPUT %d ===\n%s\n", n, input);

  if (daap_lex_parse(&result, input) == 0)
    {
      printf("=== RESULT ===\n%s\n", result.str);
      if (strcmp(expected, result.str) == 0)
        printf("=== SUCCES ===\n");
      else
        printf("==! UNEXPECTED !==\n%s\n", expected);
    }
  else
    printf("==! FAILED !==\n%s\n", result.errmsg);
}

static void
smartpl_test_parse(int n, char *input, char *expected)
{
  struct smartpl_result result;
  char buf[1024];
  int offset = 0;

  printf("=== INPUT %d ===\n%s\n", n, input);

  if (smartpl_lex_parse(&result, input) == 0)
    {
      printf("=== RESULT ===\n");
      offset += snprintf(buf + offset, sizeof(buf) - offset, "%s: WHERE %s", result.title, result.where);
      if (result.having)
        offset += snprintf(buf + offset, sizeof(buf) - offset, " HAVING %s", result.having);
      if (result.order)
        offset += snprintf(buf + offset, sizeof(buf) - offset, " ORDER BY %s", result.order);
      if (result.limit)
        offset += snprintf(buf + offset, sizeof(buf) - offset, " LIMIT %d", result.limit);
      printf("%s\n", buf);
      if (strcmp(expected, buf) == 0)
        printf("=== SUCCES ===\n");
      else
        printf("==! UNEXPECTED !==\n%s\n", expected);
    }
  else
    printf("==! FAILED !==\n%s\n", result.errmsg);
}

static void daap_test(int from, int to)
{
  // daap_debug = 1;
  for (int i = from; i <= to; i++)
    {
      daap_test_lexer(daap_test_queries[i].input, daap_test_queries[i].expected);
      daap_test_parse(i, daap_test_queries[i].input, daap_test_queries[i].expected);
      printf("\n");
    }
}

static void smartpl_test(int from, int to)
{
  // smartpl_debug = 1;
  for (int i = from; i <= to; i++)
    {
      smartpl_test_lexer(smartpl_test_queries[i].input, smartpl_test_queries[i].expected);
      smartpl_test_parse(i, smartpl_test_queries[i].input, smartpl_test_queries[i].expected);
      printf("\n");
    }
}

int main(int argc, char *argv[])
{
  int from, to;

  if ( argc == 4 && (from = atoi(argv[2])) > (to = atoi(argv[3])) )
    goto bad_args;
  else if ( argc == 3 && (from = atoi(argv[2])) > (to = atoi(argv[2])) )
    goto bad_args;
  else if (argc < 3 || argc > 4)
    goto bad_args;

  if (strcmp(argv[1], "daap") == 0)
    daap_test(from, to);
  else if (strcmp(argv[1], "smartpl") == 0)
    smartpl_test(from, to);
  else
    goto bad_args;

  return 0;

 bad_args:
  printf("Bad argumnents\n");
  return 1;
}
