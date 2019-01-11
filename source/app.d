import std.stdio;
import std.file;

import std.experimental.xml;

static struct MyHandler(NodeType)
{
	/**
	* We Can use
	*	onDocument,
	*	onElementStart,
	*	onElementEnd, 
	*	onElementEmpty, 
	*	onText, 
	*	onComment,
	*	onProcessingInstruction,
	*	onCDataSection
	*/
	void onDocument(ref NodeType node) {
		nodes = [];
		writeln("Starting new document");
	}

	void onElementEnd(ref NodeType node) {
		writeln("Node found: ", node.name);
		nodes ~= node.name;
	}
}

auto cursorErrorCallBack = (CursorError  err) {
	// Do nothing
};

string[] nodes;

void main() {
	import std.path : baseName, dirSeparator, setExtension, stripExtension;

	foreach (file; dirEntries("xml", "*.xml", SpanMode.shallow)) {
		string contents = readText(file);

		auto saxParser =
			contents
				.parser
				.cursor(cursorErrorCallBack)
				.saxParser!MyHandler;

		saxParser.processDocument;

		File fl = File("output" ~ dirSeparator ~  file.baseName.setExtension("d"), "w");
		fl.write("module xcb." ~ file.baseName.stripExtension() ~ ";");
	}
}
