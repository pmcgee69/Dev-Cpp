//! Dev-C++'s class browser tokenizer, ported by hand from `Source\VCL\ClassBrowsing\CppTokenizer.delf`
//! (which is still pass 1, so it reads as the Delphi). The aim is the same tokens, byte for byte,
//! as the Delphi version with DelfCpp's fixes (errors 21-23), checked by `compare.ps1`.
//!
//! The text is UTF-16 code units (`u16`), as Delphi's `string` is, with a terminating 0 as the
//! Delphi code relies on. A `PChar` becomes an index (`cur`); a read past the end, which Delphi
//! allows silently, panics here.
//!
//! Marked `DELPHI:` where the port keeps a behaviour of the original that Rust made visible.

/// One token: its text and the line it starts on (Delphi `TToken`).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Token {
    pub text: Vec<u16>,
    pub line: i32,
}

impl Token {
    pub fn text_string(&self) -> String {
        String::from_utf16_lossy(&self.text)
    }
}

/// What `TokenizeBuffer` raises in Delphi: `StrToInt` on an `#include` line's text after its
/// last `:` (EConvertError). The tokens before it are kept, as Delphi's list keeps them.
#[derive(Debug, PartialEq, Eq)]
pub enum TokError {
    Convert(String),
}

// CharUtils' sets (Def*Chars), all ASCII
const NUL: u16 = 0;
fn c(ch: char) -> u16 {
    ch as u16
}
fn is_line(ch: u16) -> bool {
    ch == 13 || ch == 10
}
fn is_space(ch: u16) -> bool {
    ch == 32 || ch == 9
}
fn is_digit(ch: u16) -> bool {
    (c('0')..=c('9')).contains(&ch)
}
fn is_letter(ch: u16) -> bool {
    (c('A')..=c('Z')).contains(&ch)
        || (c('a')..=c('z')).contains(&ch)
        || ch == c('_')
        || ch == c('*')
        || ch == c('&')
        || ch == c('~')
}
fn is_hex(ch: u16) -> bool {
    (c('A')..=c('F')).contains(&ch) || (c('a')..=c('f')).contains(&ch) || ch == c('x') || ch == c('L')
}
fn is_operator(ch: u16) -> bool {
    // DefOperatorChars, which lists '!' twice (FPC refused that; see delfcpp-wasm)
    "+-/*[]=%!&|><^".encode_utf16().any(|o| o == ch)
}
fn is_blank(ch: u16) -> bool {
    ch <= 32
}

fn w(s: &str) -> Vec<u16> {
    s.encode_utf16().collect()
}

/// `Pos`/`PosEx`, 0-based: the first `needle` at or after `from`.
fn find(hay: &[u16], needle: &[u16], from: usize) -> Option<usize> {
    if needle.is_empty() || from >= hay.len() || needle.len() > hay.len() - from {
        return None;
    }
    (from..=hay.len() - needle.len()).find(|&i| &hay[i..i + needle.len()] == needle)
}

/// cbutils' `FastStringReplace(S, Old, '', [rfReplaceAll])`
fn remove_all(s: &[u16], old: &[u16]) -> Vec<u16> {
    let mut out = Vec::with_capacity(s.len());
    let mut i = 0;
    while i < s.len() {
        if s.len() - i >= old.len() && &s[i..i + old.len()] == old {
            i += old.len();
        } else {
            out.push(s[i]);
            i += 1;
        }
    }
    out
}

/// Delphi's `Trim`: drops characters up to `' '` at both ends.
fn trim(s: &[u16]) -> Vec<u16> {
    let start = s.iter().position(|&ch| ch > 32).unwrap_or(s.len());
    let end = s.iter().rposition(|&ch| ch > 32).map_or(start, |e| e + 1);
    s[start..end].to_vec()
}

/// Delphi's `StrToInt` (through `Val`): leading blanks, a sign, `$`/`0x`/`x` hex or decimal,
/// nothing after, within `Integer`.
fn str_to_int(s: &[u16]) -> Option<i32> {
    let s = String::from_utf16_lossy(s);
    let t = s.trim_start_matches([' ', '\t']);
    let (neg, t) = match t.as_bytes().first() {
        Some(b'-') => (true, &t[1..]),
        Some(b'+') => (false, &t[1..]),
        _ => (false, t),
    };
    let (radix, digits) = if let Some(h) = t.strip_prefix('$') {
        (16, h)
    } else if let Some(h) = t.strip_prefix("0x").or_else(|| t.strip_prefix("0X")) {
        (16, h)
    } else if let Some(h) = t.strip_prefix('x').or_else(|| t.strip_prefix('X')) {
        (16, h)
    } else {
        (10, t)
    };
    if digits.is_empty() || !digits.chars().all(|ch| ch.is_digit(radix)) {
        return None;
    }
    let v = i64::from_str_radix(digits, radix).ok()?;
    let v = if neg { -v } else { v };
    i32::try_from(v).ok()
}

pub struct Tokenizer {
    t: Vec<u16>, // the text and its terminating 0
    cur: usize,  // pCurrent
    line_count: usize, // pLineCount
    last_token: Vec<u16>,
    curr_line: i32,
    pub tokens: Vec<Token>,
}

impl Default for Tokenizer {
    fn default() -> Self {
        Self::new()
    }
}

impl Tokenizer {
    pub fn new() -> Self {
        Tokenizer { t: vec![NUL], cur: 0, line_count: 0, last_token: Vec::new(), curr_line: 1, tokens: Vec::new() }
    }

    fn at(&self, i: usize) -> u16 {
        self.t[i]
    }
    fn ch(&self) -> u16 {
        self.t[self.cur]
    }
    fn next(&self) -> u16 {
        self.t[self.cur + 1]
    }

    fn add_token(&mut self, text: Vec<u16>, line: i32) {
        self.tokens.push(Token { text, line });
    }

    fn count_lines(&mut self) {
        while self.at(self.line_count) != NUL && self.line_count < self.cur {
            if self.at(self.line_count) == 10 {
                self.curr_line += 1;
            }
            self.line_count += 1;
        }
    }

    fn skip_c_style_comment(&mut self) {
        loop {
            self.cur += 1;
            if self.ch() == NUL || (self.ch() == c('*') && self.next() == c('/')) {
                break;
            }
        }
        if self.ch() != NUL {
            self.cur += 2; // skip '*/'
        }
    }

    fn skip_split_line(&mut self) {
        self.cur += 1; // skip '\'
        while is_line(self.ch()) {
            self.cur += 1;
        }
    }

    fn skip_to_eol(&mut self) {
        while !is_line(self.ch()) && self.ch() != NUL {
            if self.ch() == c('/') && self.next() == c('*') {
                self.skip_c_style_comment();
            } else {
                self.cur += 1;
            }
        }
        let split_line = self.at(self.cur - 1) == c('\\') && is_line(self.ch());
        while is_line(self.ch()) {
            self.cur += 1;
        }
        if split_line {
            self.skip_to_eol();
        }
    }

    fn skip_to_next_token(&mut self) {
        while is_space(self.ch()) || is_line(self.ch()) {
            self.advance();
        }
    }

    fn skip_quoted(&mut self, quote: u16) {
        // SkipDoubleQuotes and SkipSingleQuote, with DelfCpp's fixes (errors 21, 22)
        self.cur += 1;
        while self.ch() != quote && self.ch() != NUL {
            if self.ch() == c('\\') && self.next() != NUL {
                self.cur += 2;
            } else {
                self.cur += 1;
            }
        }
        if self.ch() != NUL {
            self.cur += 1;
        }
    }

    fn skip_pair(&mut self, start: u16, end: u16, fail: &[u16]) {
        self.cur += 1;
        while self.ch() != NUL {
            let ch = self.ch();
            if ch == start {
                self.skip_pair(start, end, fail);
            } else if ch == end {
                self.cur += 1;
                break;
            } else if ch == c('"') {
                if start != c('\'') {
                    self.skip_quoted(c('"'));
                } else {
                    self.cur += 1;
                }
            } else if ch == c('\'') {
                self.skip_quoted(c('\''));
            } else if ch == c('/') {
                if self.next() == c('/') {
                    self.skip_to_eol();
                } else if self.next() == c('*') {
                    self.skip_c_style_comment();
                } else {
                    self.cur += 1;
                }
            } else if fail.contains(&ch) {
                return;
            } else {
                self.cur += 1;
            }
        }
    }

    fn skip_assignment(&mut self) {
        loop {
            match char::from_u32(self.ch() as u32) {
                Some('(') => self.skip_pair(c('('), c(')'), &[]),
                Some('"') => self.skip_quoted(c('"')),
                Some('\'') => self.skip_quoted(c('\'')),
                Some('{') => self.skip_pair(c('{'), c('}'), &[]),
                Some('/') => {
                    if self.next() == c('/') {
                        self.skip_to_eol();
                    } else if self.next() == c('*') {
                        self.skip_c_style_comment();
                    } else {
                        self.cur += 1;
                    }
                }
                _ => self.cur += 1,
            }
            if [c(','), c(';'), c(')'), c('}'), NUL].contains(&self.ch()) {
                break;
            }
        }
    }

    fn skip_template_args(&mut self) {
        let start = self.cur;
        if self.ch() != c('<') {
            return;
        }
        self.skip_pair(c('<'), c('>'), &[c('{'), c('}'), c(';')]);
        if self.at(self.cur - 1) != c('>') {
            self.cur = start;
        }
    }

    fn advance(&mut self) {
        let ch = self.ch();
        if ch == c('"') {
            self.skip_quoted(c('"'));
        } else if ch == c('\'') {
            self.skip_quoted(c('\''));
        } else if ch == c('/') {
            match self.next() {
                n if n == c('*') => self.skip_c_style_comment(),
                n if n == c('/') => self.skip_to_eol(),
                n if n == c('=') => self.skip_assignment(),
                _ => self.cur += 1,
            }
        } else if ch == c('=') {
            self.skip_assignment();
        } else if "&*!|+-~".encode_utf16().any(|o| o == ch) {
            if self.next() == c('=') {
                self.skip_assignment();
            } else {
                self.cur += 1;
            }
        } else if ch == c('\\') {
            if is_line(self.next()) {
                self.skip_split_line();
            } else {
                self.cur += 1;
            }
        } else {
            self.cur += 1;
        }
    }

    fn get_number(&mut self) -> Vec<u16> {
        let offset = self.cur;
        // Delphi: `if pCurrent^.IsDigit`, always true here (only called when IsNumber)
        if is_digit(self.ch()) {
            while is_digit(self.ch()) || is_hex(self.ch()) {
                self.advance();
            }
        }
        if offset != self.cur {
            let mut result = self.t[offset..self.cur].to_vec();
            if self.ch() == c('.') {
                result.push(c('.')); // kept, not stepped over
            }
            result
        } else {
            Vec::new()
        }
    }

    fn get_word(&mut self, skip_parenthesis: bool, skip_array: bool, skip_block: bool) -> Vec<u16> {
        self.skip_to_next_token();
        let mut offset = self.cur;
        while is_letter(self.ch()) || is_digit(self.ch()) {
            self.cur += 1;
        }
        if self.t[offset..self.cur] == w("operator")[..] {
            while is_space(self.ch()) {
                self.cur += 1;
            }
            while is_operator(self.ch()) {
                self.cur += 1;
            }
        }
        if offset == self.cur {
            return Vec::new();
        }
        let mut result = self.t[offset..self.cur].to_vec();
        self.skip_to_next_token();

        if self.ch() == c('<') {
            self.skip_template_args();
        } else if skip_array && self.ch() == c('[') {
            loop {
                offset = self.cur;
                let mut depth = 1;
                loop {
                    loop {
                        self.cur += 1;
                        if self.ch() == c('[') {
                            depth += 1;
                        }
                        if self.ch() == NUL || self.ch() == c(']') || is_line(self.ch()) {
                            break;
                        }
                    }
                    depth -= 1;
                    if depth == 0 || self.ch() == NUL {
                        break; // error 23's fix: stop at the end
                    }
                }
                if self.ch() != NUL {
                    self.cur += 1;
                }
                result.extend_from_slice(&self.t[offset..self.cur]);
                self.skip_to_next_token();
                if self.ch() != c('[') {
                    break;
                }
            }
        } else if skip_block && self.ch() == c('{') {
            self.skip_pair(c('{'), c('}'), &[]);
            self.skip_to_next_token();
        }

        if self.ch() == c('.') {
            result.push(c('.'));
            self.cur += 1;
        } else if self.ch() == c('-') && self.next() == c('>') {
            result.extend_from_slice(&w("->"));
            self.cur += 2;
        } else if self.ch() == c(':') && self.next() == c(':') {
            result.extend_from_slice(&w("::"));
            self.cur += 2;
            let s = self.get_word(skip_parenthesis, skip_array, skip_block);
            result.extend_from_slice(&s);
        }
        result
    }

    fn get_preprocessor(&mut self) -> Vec<u16> {
        let offset = self.cur;
        self.skip_to_eol();
        self.t[offset..self.cur].to_vec()
    }

    fn get_arguments(&mut self) -> Vec<u16> {
        let offset = self.cur;
        self.skip_pair(c('('), c(')'), &[]);
        let mut result = self.t[offset..self.cur].to_vec();
        simplify_args(&mut result);
        if self.ch() == c('.') || (self.ch() == c('-') && self.next() == c('>')) {
            while ![NUL, c('('), c(';'), c('{'), c('}'), c(')')].contains(&self.ch())
                && !is_line(self.ch())
                && !is_space(self.ch())
            {
                self.cur += 1;
            }
        }
        self.skip_to_next_token();
        result
    }

    /// DELPHI: `GetForInit: String` never assigns `Result`. Delphi lets it compile, and the
    /// caller gets an empty string (dcc passes the caller's own result, which it has set to '').
    /// Rust won't compile a function that doesn't return its value, so the port says it: the
    /// tokens go straight into the list and the function returns nothing to its caller.
    fn get_for_init(&mut self) -> Result<Vec<u16>, TokError> {
        let start_offset = self.cur;
        self.cur += 1;
        loop {
            let mut s = self.get_next_token(true, true, false)?;
            simplify(&mut s);
            if !s.is_empty() {
                let line = self.curr_line;
                self.add_token(s.clone(), line);
            }
            if s.is_empty() || s == [c(';')] {
                break;
            }
        }
        self.cur = start_offset;
        self.skip_pair(c('('), c(')'), &[]);
        Ok(Vec::new())
    }

    fn get_next_token(&mut self, _skip_parenthesis: bool, skip_array: bool, skip_block: bool) -> Result<Vec<u16>, TokError> {
        let mut result: Vec<u16> = Vec::new();
        loop {
            self.skip_to_next_token();
            if self.ch() == NUL {
                break;
            }
            let ch = self.ch();
            let done;
            if ch == c('#') {
                self.count_lines();
                result = self.get_preprocessor();
                if result.starts_with(&w("#include")) {
                    if let Some(delim) = result.iter().rposition(|&x| x == c(':')) {
                        let tail = &result[delim + 1..];
                        let end = tail.iter().rposition(|&x| x > 32).map_or(0, |e| e + 1);
                        match str_to_int(&tail[..end]) {
                            Some(n) => self.curr_line = n.wrapping_sub(1),
                            None => return Err(TokError::Convert(String::from_utf16_lossy(&tail[..end]))),
                        }
                    }
                }
                done = !result.is_empty();
            } else if ch == c('(') && self.last_token == w("for") {
                self.count_lines();
                result = self.get_for_init()?;
                done = !result.is_empty();
            } else if ch == c('(') {
                self.count_lines();
                result = self.get_arguments();
                done = !result.is_empty();
            } else if is_letter(ch) {
                self.count_lines();
                result = self.get_word(false, skip_array, skip_block);
                done = !result.is_empty();
            } else if is_digit(ch) {
                self.count_lines();
                result = self.get_number();
                done = !result.is_empty();
            } else if ch == c('/') {
                match self.next() {
                    n if n == c('*') => self.skip_c_style_comment(),
                    n if n == c('/') => self.skip_to_eol(),
                    _ => self.advance(),
                }
                done = false;
            } else if [c('{'), c('}'), c(';'), c(','), c(':')].contains(&ch) {
                self.count_lines();
                result = vec![ch];
                self.advance();
                done = true;
            } else if (ch == c('>') || ch == c('<')) && self.next() == ch {
                self.count_lines();
                result = vec![ch, ch];
                self.advance(); // one character: ">>>" gives two ">>"
                done = true;
            } else {
                self.advance();
                done = false;
            }
            if done {
                break;
            }
        }
        Ok(result)
    }

    /// `TokenizeBuffer`: the text up to its first 0. On an error the tokens so far are kept.
    pub fn tokenize(&mut self, text: &[u16]) -> Result<(), TokError> {
        self.tokens.clear();
        let len = text.iter().position(|&x| x == NUL).unwrap_or(text.len());
        self.t = text[..len].to_vec();
        self.t.push(NUL);
        self.cur = 0;
        self.line_count = 0;
        self.curr_line = 1;
        let mut s: Vec<u16> = Vec::new();
        loop {
            self.last_token = s.clone();
            s = self.get_next_token(true, true, false)?;
            simplify(&mut s);
            if !s.is_empty() {
                let line = self.curr_line;
                self.add_token(s.clone(), line);
            }
            if s.is_empty() {
                break;
            }
        }
        Ok(())
    }
}

/// `Simplify`: comments, line splices and line breaks out, then trimmed.
fn simplify(out: &mut Vec<u16>) {
    // DELPHI: PosEx('*/', Output, DelimPosFrom) searches from the '/' of '/*' itself, so "/*/"
    // counts as a whole comment. Kept.
    while let Some(from) = find(out, &w("/*"), 0) {
        match find(out, &w("*/"), from) {
            Some(to) => {
                out.drain(from..to + 2);
            }
            None => break,
        }
    }
    while let Some(from) = find(out, &w("//"), 0) {
        match find(out, &[10], from) {
            Some(to) => {
                out.drain(from..to + 1);
            }
            None => break,
        }
    }
    let mut s = remove_all(out, &[c('\\'), 13]);
    s = remove_all(&s, &[c('\\'), 10]);
    s = remove_all(&s, &[13]);
    s = remove_all(&s, &[10]);
    *out = trim(&s);
}

/// `SimplifyArgs`: an argument list formatted as "(int a, int b, int c)". Written with Delphi's
/// 1-based indexes (`o1`) so it can be read against the original line by line.
fn simplify_args(o: &mut Vec<u16>) {
    // DELPHI: Output[Length + 1], one past the end, is read below (the "remove before" test with
    // Head = Index = Length). With range checks off Delphi reads the string's terminating #0,
    // which is blank. Rust's indexing panics, so the read is made explicit: past the end is 0.
    fn o1(o: &[u16], i: isize) -> u16 {
        if i >= 1 && (i as usize) <= o.len() {
            o[i as usize - 1]
        } else if i as usize == o.len() + 1 {
            NUL
        } else {
            panic!("SimplifyArgs: index {i} outside the string (length {})", o.len())
        }
    }
    fn delete(o: &mut Vec<u16>, index: isize, count: isize) {
        // Delphi's Delete: 1-based, clamped, nothing for a count <= 0
        if count <= 0 || index < 1 || index as usize > o.len() {
            return;
        }
        let from = index as usize - 1;
        let to = (from + count as usize).min(o.len());
        o.drain(from..to);
    }
    fn format_spaces_around(o: &mut Vec<u16>, index: isize, insert_count: usize) {
        let mut insert_index = index + 1;
        // Remove all before. DELPHI: Head starts at Index, the comma or brace itself, which isn't
        // blank, so this removes nothing unless Output[Index] is a blank (an unclosed list).
        if index > 1 {
            let mut head = index;
            while head > 0 && is_blank(o1(o, head)) {
                head -= 1;
            }
            if head - 1 > 0 && is_blank(o1(o, head + 1)) {
                delete(o, head, index - head);
                insert_index -= index - head;
            }
        }
        // Remove all after
        let len = o.len() as isize;
        if index + 1 < len {
            let mut head = index + 1;
            while head <= o.len() as isize && is_blank(o1(o, head)) {
                head += 1;
            }
            if head - 1 <= o.len() as isize && is_blank(o1(o, head - 1)) {
                delete(o, index + 1, head - index - 1);
            }
        }
        // Insert at starting position (Delphi's Insert clamps to the end)
        if insert_count > 0 {
            let at = ((insert_index.max(1) - 1) as usize).min(o.len());
            for _ in 0..insert_count {
                o.insert(at, c(' '));
            }
        }
    }

    if o.is_empty() {
        return;
    }
    format_spaces_around(o, 1, 0);
    let mut search_start = 1isize;
    while let Some(comma) = find(o, &[c(',')], (search_start - 1) as usize) {
        let comma = comma as isize + 1;
        format_spaces_around(o, comma, 1);
        search_start = comma + 1;
    }
    let len = o.len() as isize;
    format_spaces_around(o, len, 0);
}

#[cfg(test)]
mod tests {
    use super::*;

    fn toks(src: &str) -> Vec<(i32, String)> {
        let mut t = Tokenizer::new();
        t.tokenize(&w(src)).unwrap();
        t.tokens.iter().map(|k| (k.line, k.text_string())).collect()
    }

    #[test]
    fn words_braces_and_lines() {
        assert_eq!(
            toks("int main()\n{\n  return 0;\n}\n"),
            vec![(1, "int".into()), (1, "main".into()), (1, "()".into()), (2, "{".into()),
                 (3, "return".into()), (3, "0".into()), (3, ";".into()), (4, "}".into())]
        );
    }

    #[test]
    fn arguments_are_formatted() {
        // What Delphi gives (the corpus comparison agrees): blanks after '(' and after each comma
        // go, one space goes after each comma; the "remove before" half never runs, so the space
        // before the comma and before ')' stays. The comment's aim was "(int a, int b)".
        assert_eq!(toks("f( int a ,int b )")[1].1, "(int a , int b )");
    }

    #[test]
    fn unterminated_literals_stop_at_the_end() {
        // errors 21-23: the Delphi original read past the end here; Rust would panic
        toks("x = \"abc");
        toks("x = 'a\\");
        toks("a[");
    }

    #[test]
    fn include_with_bad_line_number_is_an_error() {
        let mut t = Tokenizer::new();
        assert!(t.tokenize(&w("#include <a> // see: below\nint x;")).is_err());
    }
}
