import std.stdio;
import std.file;

import std.experimental.xml;

static struct MyHandler(NodeType)
{
	/**
	 * We Can use
	 * 	onDocument,
	 * 	onElementStart,
	 * 	onElementEnd, 
	 * 	onElementEmpty, 
	 * 	onText, 
	 * 	onComment,
	 * 	onProcessingInstruction,
	 * 	onCDataSection
	 */
	void onDocument(ref NodeType node) {
		writeln("Starting new document");
	}

    void onElementEnd(ref NodeType node) {
		writeln("Node found: ", node.name);
    }
}

auto cursorErrorCallBack = (CursorError  err) {
	// Do nothing
};

void main() {
	foreach (file; dirEntries("xml", "*.xml", SpanMode.shallow)) {
		string contents = readText(file);

		auto saxParser =
			contents
				.parser
				.cursor(cursorErrorCallBack)
				.saxParser!MyHandler;

		saxParser.processDocument;
	}
}
