module parsers.xcb_enum;

import std.stdio : File;
import parsers.parser;

import std.typecons : Tuple, tuple;

public void parseXcbEnum(T)(ref T cursor, ref File outFile) @trusted {
	string enumName = cursor.attributes.front.value;
	string[] values;

	outFile.write("enum " ~ enumName ~ " {\n");
	if (cursor.enter()) {
			do {
				auto attrs = cursor.attributes;

				if (attrs.empty()) {
					continue;
				}

				string name = attrs.front.value;
				cursor.enter();
				bool isBit = cursor.content() == "bit";
				cursor.enter();
				string value = cursor.content;
				cursor.exit();
				cursor.exit();

				if (isBit) {
					outFile.write("\t" ~ name ~ " = 1 << " ~ value ~ ";\n");
				} else {
					outFile.write("\t" ~ name ~ " = " ~ value ~ ";\n");
				}

				values ~= name;
			} while (cursor.next());

		cursor.exit();
	}
	outFile.write("}\n");

	foreach (v; values) {
		outFile.write("alias  " ~ v ~ " = " ~ enumName ~ "." ~ v ~ ";\n");
	}
}