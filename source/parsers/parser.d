module parsers.parser;

import std.path : baseName, dirSeparator, setExtension, stripExtension;
import std.stdio;
import std.file;

public import std.experimental.logger;
public import std.experimental.xml;

private import parsers.xcb_enum;
private import parsers.xcb_struct;


static class Parser {
public static:
	void parseXmlFiles() @trusted {
		createOutDir();

		foreach (file; dirEntries("xml", "*.xml", SpanMode.shallow)) {
			info("Parsing file ", file);

			string contents = readText(file);

			auto cursor = contents
				.parser
				.cursor(cursorErrorCallBack);
			
			cursor.setSource(contents);

			File fl = initializeFile(file);
			parseCursor(cursor, fl);
		}
	}

private static:
	void createOutDir() {
		if (!exists("output")) {
			mkdir("output");
		}
	}

	File initializeFile(string path) @trusted {
		string fileName = path.baseName;
		File fl = File("output" ~ dirSeparator ~ fileName.setExtension("d"), "w");
		fl.write("module xcb." ~ fileName.stripExtension ~";\n\npublic extern(C) nothrow @nogc:\n\n");

		return fl;
	}

	void parseCursor(T)(ref T cursor, File fl) {
		do {
			switch (cursor.name) {
				case "struct":
					parseXcbStruct(cursor, fl);
					break;

				case "enum":
					parseXcbEnum(cursor, fl);
					break;

				default:
					if (cursor.kind == XMLKind.elementStart) {
						warning("Cannot parse the element '", cursor.name, "'");
					}
					break;
			}

			// if the current node has children, inspect them recursively
			if (cursor.enter) {
				parseCursor(cursor, fl);
				cursor.exit;
			}
		}
		while (cursor.next);
	}

	auto cursorErrorCallBack = (CursorError  err) {
		// Do nothing
	};
}