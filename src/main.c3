module pugc;
import std::io;
import std::io::file;


struct FileContents {
  usz len;
  char* buff;
}

enum LexPhase {
  TEXT, DOT, HASHTAG, LEFT_BRACE, RIGHT_BRACE, COMMA, PIPE, DIGT, EQ, PLUS, SPACE, NEW_LINE
}

enum TokenType {
  TEXT, PROP_KEY, PROP_VAL, TAG, ID, CLASS, EXPR
}

struct Token {
  Token* next;
  char* buff;
  usz len;
  int spaces;
  TokenType typ;
}

faultdef CODE_NOT_FOUND, PROPS_ERROR;

fn String Token.type_name(Token* self) {
  switch (self.typ){
    case TEXT:
      return "text";
    case PROP_KEY:
      return "pkey";
    case PROP_VAL:
      return "pval";
    case TAG:
      return "tag";
    case ID:
      return "id";
    case CLASS:
      return "class";
    case EXPR:
      return "expr";
    default:
      return "unknown";
  }
}

fn void Token.print(Token* self) {
  Token *pt = self;

  while((pt = pt.next) != null) {
    debug("[%s] %s", pt.type_name(), (String)pt.buff[:pt.len]);
  }
}

fn void debug(String format, args...) {
  io::printfn(format, ...args);
}

fn FileContents*? load_file(String filename) {
  File f = file::open(filename, "rb")!; // ! retrow exception if ocurre
  defer (void)f.close();
  usz len = f.seek(0, END)!;
  f.seek(0, SET)!;

  char* buffer = malloc(len);
  usz read = f.read(buffer[:len])!;

  FileContents* fc = malloc(FileContents.sizeof);
  fc.len = len;
  fc.buff = buffer[:len] ;
  
  return fc;
}


fn Token* new_token(TokenType typ, char* val, int len, int spaces) {
  Token* t = malloc(Token.sizeof);
  t.buff = val;
  t.typ = typ;
  t.len = len;
  t.spaces = spaces;
  t.next = null;
  return t;
}

// get text until found char code. return text len
fn int? count_chars_until_code(char* buff, usz len, char* code) {
  int i = 0;
  char* pt = buff;
  while(i < len) {
    if (*pt == *code) {
      return i;
    }
    i++;
    pt++;
  }
  return CODE_NOT_FOUND?;
}


fn int? count_chars_until_codes(char* buff, usz len, char[] codes) {
  int i = 0;
  char* pt = buff;
  while(i < len) {

    foreach(&code : codes) {
      if (*pt == *code) {
	return i;
      }
    }

    i++;
    pt++;
  }
  return CODE_NOT_FOUND?;
}

fn int? find_props(char* buff, usz len, Token* token) {

  char *c = buff;
  LexPhase phase;
  TokenType typ;

  Token* pt = token;
  char* start = c;
  int idx = 0;
  // (id="", data-id="10", class="x")
  // (id="1" data-id="10" class="y")
  for(int i = 0; i < len; i++) {
    switch (*c++) {
      case '=':
	int size = i-idx;
	debug("set prop key %d, %s", size, (String)start[:size]);
        pt.next = new_token(PROP_KEY, start, size, 0);
        pt = pt.next;
	idx = i+1;
        start = c;

        // prop val
      case ',':
	int size = i-idx;
	debug("set prop val %d, %s", size, (String)start[:size]);
        pt.next = new_token(PROP_VAL, start, size, 0);
        pt = pt.next;
	idx = i+1;
        start = c;
       // prop name
      case ' ':
	idx++;
	start++;
	continue;
      case ')':

	int size = i-idx;
        pt.next = new_token(PROP_VAL, start, size, 0);
	debug("set prop val %d, %s", size, (String)start[:size]);
	debug("end = %d", i);
	return i+1;
       // prop name
      case '\'':
	start = c;
	idx = i + 1;
	while(++i < len) {
	  if(*++c == '\'') {
	    break;
	  }
	}
	c++;
      case '\"':
	start = c;
	idx = i + 1;
	while(++i < len) {
	  if(*++c == '\"') {
	    break;
	  }
	}
	c++;
      default:
	continue;
       // get 
    }
  }
  

  return PROPS_ERROR?;
  
}

fn void? lex(FileContents* fc) {

  debug("%s", (String)fc.buff[:fc.len-1]);
  
  Token* head = malloc(Token.sizeof);

  char* word;
  char len;
  int lineNumber = 1;
  bool intoProps = false;
  bool intoCode = false;
  int ident = 0;

  Token* pt = head;
  LexPhase phase;
  TokenType typ;
  
  for(int i = 0; i < fc.len; i++) {
    char* c = fc.buff++;
    
    switch M: (*c) {
      case ' ':
	ident++;
      case '\t':
	ident+=4;
      case '\n':
	ident = 0;
	lineNumber++;
	intoCode = false;
      case '-':
	pt.next = new_token(typ, c, 1, ident);
	pt = pt.next;
	ident = 0;
	intoCode = true;
      case '=':
	int size = count_chars_until_codes(++c, fc.len, {'\n', '\0'})!;
	pt.next = new_token(TEXT, c, size, 0);
	pt = pt.next;
	i += size;
	fc.buff += size;
//      case '+':
// TODO: plus
      case '.':	
	int size = count_chars_until_codes(++c, fc.len, {'.', '#', '(', '\n', '\0'})!;
	pt.next = new_token(CLASS, c, size, 0);
	pt = pt.next;
	i += size;
	fc.buff += size;
      case '#':
	int size = count_chars_until_codes(++c, fc.len, {'.', '(', '\n', '\0'})!;
	pt.next = new_token(ID, c, size, 0);
	pt = pt.next;
	i += size;
	fc.buff += size;

      case '(':
	// skip (
	i++;
	fc.buff++;
	// find until )
	int size = find_props(++c, fc.len, pt)!;
        i += size;
	fc.buff += size;
	while(pt.next != null){
	  pt = pt.next;
	}

      case ')':
	int size = count_chars_until_codes(++c, fc.len, {'\n', '\0'})!;
	pt.next = new_token(TEXT, c, size, 0);
	pt = pt.next;
	i += size;
	fc.buff += size;
	
      case '|':
	// read until new line or eof
	char[*] codes = {'\n', '\0'};
	int idx = i+1;	  
	char* start = ++c;
	int size = count_chars_until_codes(start, fc.len, codes[:2])!;
	pt.next = new_token(TEXT, start, size, 0);
	pt = pt.next;
	i = idx + size;
	fc.buff += size+1;
	
      default: // word

	debug("c=%s,next=%c,ident=%d",*c==' ',*(c+1), ident);
	
	int size = count_chars_until_codes(c, fc.len, {' ', '.', '#',  '(', '\n', '\0'})!;
	pt.next = new_token(TAG, c, size, 0);
	pt = pt.next;
	i += size;
	fc.buff += size;
	c = fc.buff-1;

	if(*c == ' ') {
	  size = count_chars_until_codes(++c, fc.len, {'\n', '\0'})!;
	  pt.next = new_token(TEXT, c, size, 0);
	  pt = pt.next;
	  i += size;
	  fc.buff += size;
	} else {
	  fc.buff--;
	  i--;
	}

	/*
	int idx = i;	  
	char* start = c;

	// um texto, comeca com ' ou "
	switch(*c) {
	  case '\'':
	    idx = i+1;
	    // ++c pula para o próximo caracter, já que está no apostrofe
	    int size = count_chars_until_code(++c, fc.len, &&'\'')!;
	    // ++start ignora o apostrofe.
	    // A função until retorna o index que precede o char encontrado 
	    pt.next = new_token(TEXT, ++start, size, 0);
	    pt = pt.next;
	    fc.buff += size+2; // + 2 apostrofes, incio e fim
	    i = idx + size;
	    break M;
	  case '"':
	    idx = i+1;
	    int size = count_chars_until_code(++c, fc.len, &&'\"')!;
	    pt.next = new_token(TEXT, ++start, size, 0);
	    pt = pt.next;
	    fc.buff += size+2;
	    i = idx + size;
	    break M;
	}

	char[*] codes = {'.', '#', '=', '(', ')', '\n', '\'', '\"', ',', '\0', ' '};
        int size = count_chars_until_codes(c, fc.len, codes[:11])!;
	pt.next = new_token(TEXT, start, size, 0);
	pt = pt.next;
	fc.buff += size;
	i = idx + size;
	      
	
	// se não encontra nada, então fim de arquivo
	int l = (int)fc.len-1-i;
	pt.next = new_token(TEXT, start, l, 0);
	pt = pt.next;
	i = (int)fc.len;
	break M;
       */
    }
  }


  head.print();
}

fn int main(String[] args)
{

  FileContents*? fc = load_file("./resources/main.pug");

  if (catch err = fc) {
    // handle error
    io::eprintfn("Error: could not load file");
    return 1;
  }

  defer free(fc);

  if (catch err = lex(fc)) {
    debug("error: %s", err);
  }
  debug("DONE!");
  return 0;
}
