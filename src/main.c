#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "daap_parser.h"
#include "smartpl_parser.h"

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

static struct test_query daap_test_queries[] =
{
  {
    "'com.apple.itunes.extended-media-kind:32'",
    "(1 = 0)"
  },
  {
    "('daap.songartist!:' ('com.apple.itunes.extended-media-kind:1','com.apple.itunes.extended-media-kind:32'))",
    "((f.media_kind = 1 OR 1 = 0))"
  },
  {
    "('daap.songalbumid:1034227734086706124' ('com.apple.itunes.extended-media-kind:4','com.apple.itunes.extended-media-kind:36','com.apple.itunes.extended-media-kind:6','com.apple.itunes.extended-media-kind:7'))",
    "((f.songalbumid = 1034227734086706124 AND (((f.media_kind = 4 OR f.media_kind = 36) OR f.media_kind = 6) OR f.media_kind = 7)))"
  },
  {
    "('daap.songartistid:6912769229437698119' ('com.apple.itunes.extended-media-kind:1','com.apple.itunes.extended-media-kind:32'))",
    "((f.songartistid = 6912769229437698119 AND (f.media_kind = 1 OR 1 = 0)))"
  },
  {
    "('com.apple.itunes.playlist-contains-media-type:1','com.apple.itunes.playlist-contains-media-type:32','com.apple.itunes.playlist-contains-media-type:128','com.apple.itunes.playlist-contains-media-type:1024','com.apple.itunes.playlist-contains-media-type:65537')",
    ""
  },
  {
    "('dmap.itemname:My Music on thundarr','com.apple.itunes.extended-media-kind@1','com.apple.itunes.extended-media-kind@32','com.apple.itunes.extended-media-kind@128','com.apple.itunes.extended-media-kind@65537')",
    "(((((f.title = 'My Music on thundarr' OR f.media_kind = 1) OR 1 = 0) OR f.media_kind = 128) OR f.media_kind = 65537))"
  },
  {
    "'daap.songgenre:Kid\\'s Audiobooks'",
    "(f.genre = 'Kid''s Audiobooks')"
  },
  {
    "'daap.songalbum!:'",
    ""
  },
  {
    "('daap.songartist:*cfbnk*' ('com.apple.itunes.mediakind:1','com.apple.itunes.mediakind:32') 'daap.songartist!:')",
    "((f.album_artist LIKE '%cfbnk%' AND (f.media_kind = 1 OR 1 = 0)))"
  },
  {
    "(('com.apple.itunes.mediakind:4','com.apple.itunes.mediakind:36','com.apple.itunes.mediakind:6','com.apple.itunes.mediakind:7') 'daap.songalbumid:1034227734086706124')",
    "(((((f.media_kind = 4 OR f.media_kind = 36) OR f.media_kind = 6) OR f.media_kind = 7) AND f.songalbumid = 1034227734086706124))"
  },
  {
    "(('com.apple.itunes.mediakind:1','com.apple.itunes.mediakind:32') 'daap.songartist!:')",
    "((f.media_kind = 1 OR 1 = 0))"
  },
};

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

static void
daap_test_parse(char *input, char *expected)
{
  struct daap_result result;

  printf("=== INPUT ===\n%s\n", input);

  if (daap_lex_parse(&result, input) == 0)
    {
      printf("=== RESULT ===\n%s\n", result.str);
      if (strcmp(expected, result.str) == 0)
        printf("=== SUCCES ===\n");
      else
        printf("==! UNEXPECTED !==\n");
    }
  else
    printf("==! FAILED !==\n");
}

static void
smartpl_test_parse(char *input, char *expected)
{
  struct smartpl_result result;
  char buf[1024];
  int offset = 0;

  printf("=== INPUT ===\n%s\n", input);

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
      daap_test_parse(daap_test_queries[i].input, daap_test_queries[i].expected);
      printf("\n");
    }
}

static void smartpl_test(int from, int to)
{
  // smartpl_debug = 1;
  for (int i = from; i <= to; i++)
    {
      smartpl_test_lexer(smartpl_test_queries[i].input, smartpl_test_queries[i].expected);
      smartpl_test_parse(smartpl_test_queries[i].input, smartpl_test_queries[i].expected);
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
