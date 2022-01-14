enum data_kind {
  DATA_KIND_FILE = 0,
  DATA_KIND_HTTP = 1,
  DATA_KIND_SPOTIFY = 2,
  DATA_KIND_PIPE = 3,
};

enum media_kind {
  MEDIA_KIND_MUSIC = 1,
  MEDIA_KIND_MOVIE = 2,
  MEDIA_KIND_PODCAST = 4,
  MEDIA_KIND_AUDIOBOOK = 8,
  MEDIA_KIND_MUSICVIDEO = 32,
  MEDIA_KIND_TVSHOW = 64,
};

struct dmap_query_field_map {
  char *dmap_field;
  char *db_col;
  int as_int;
};

struct dmap_query_field_map * daap_query_field_lookup(char *tag, int len);

char * db_escape_string(const char *str);

int safe_snreplace(char *s, size_t sz, const char *pattern, const char *replacement);
