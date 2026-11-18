//! tokdump <root> <list> <out>: tokenizes each file named in <list> (paths relative to <root>, one
//! per line) and writes "=== path", then "line<TAB>text" per token, to <out> as UTF-8.
//! Files are read as Latin-1 (each byte one character), the same as TokDump.dpr, so the two
//! versions see the same text. A token's \, tab, CR and LF are escaped. An error ends a file
//! with "!error" after the tokens before it.
use cpptokenizer::Tokenizer;
use std::fmt::Write as _;
use std::fs;

fn escape(s: &str) -> String {
    let mut o = String::with_capacity(s.len());
    for ch in s.chars() {
        match ch {
            '\\' => o.push_str("\\\\"),
            '\t' => o.push_str("\\t"),
            '\r' => o.push_str("\\r"),
            '\n' => o.push_str("\\n"),
            _ => o.push(ch),
        }
    }
    o
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 4 {
        eprintln!("usage: tokdump <root> <list> <out>");
        std::process::exit(2);
    }
    let (root, list, out) = (&args[1], &args[2], &args[3]);
    let names = fs::read_to_string(list).expect("list");
    let mut dump = String::new();
    let mut tok = Tokenizer::new();
    let mut files = 0;
    for name in names.lines().map(str::trim).filter(|l| !l.is_empty()) {
        let path = format!("{root}/{name}");
        let bytes = fs::read(&path).unwrap_or_else(|e| panic!("{path}: {e}"));
        let text: Vec<u16> = bytes.iter().map(|&b| b as u16).collect();
        writeln!(dump, "=== {name}").unwrap();
        let result = tok.tokenize(&text);
        for t in &tok.tokens {
            writeln!(dump, "{}\t{}", t.line, escape(&t.text_string())).unwrap();
        }
        if result.is_err() {
            dump.push_str("!error\n");
        }
        files += 1;
    }
    fs::write(out, dump).expect("out");
    eprintln!("tokdump (Rust): {files} files");
}
