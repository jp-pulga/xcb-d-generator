module parsers.xcb_struct;

import std.stdio : File;
import parsers.parser;

public void parseXcbStruct(T)(ref T cursor, ref File outFile) @trusted {
	string structName = cursor.attributes.front.value;

	debug {
		info("Parsing contentes for the struct ", structName);
	}

	outFile.write("struct " ~ structName ~ " {\n");

	if (cursor.enter()) {
		do {
			if (cursor.name == "field") {
				auto attrs = cursor.attributes;
				if (!attrs.empty) {
					string type = attrs.front.value;
					attrs.popFront();
					string name = attrs.front.value;

					outFile.write("\t" ~ type ~ " " ~ name ~ ";\n");
				}
			}
		} while (cursor.next());

		cursor.exit();
	}

	outFile.write("}\n\n");
}