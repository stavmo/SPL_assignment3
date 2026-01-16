/*
this class represents a STOMP frame. a frame has a type, a body and a list of headers.
    each header is a key-value pair.
    the frame types are defined in the FrameType enum.

    :)

 */

package bgu.spl.net.impl.stomp;

import java.util.Vector;

public class StompFrame {
    final private FrameType type;
    final private Vector<Header> headers;
    final private String body;

    public StompFrame(FrameType type, String body, Vector<Header> headers) {
        this.type = type;
        this.body = body;
        this.headers = headers;
    }


    //this constructor parses a raw frame string into a StompFrame object
    public StompFrame(String rawFrame) {
        // Remove trailing null terminator if present
        if (rawFrame.endsWith("\0")) {
            rawFrame = rawFrame.substring(0, rawFrame.length() - 1);
        }
        headers = new Vector<>();
        String[] lines = rawFrame.split("\n");
        type = FrameType.valueOf(lines[0]);
        int i = 1;
        while (i < lines.length && lines[i].contains(":")) {
            String[] keyValue = lines[i].split(":", 2);
            headers.add(new Header(keyValue[0], keyValue[1]));
            i++;
        }
        String bodyStr = "";
        while (i < lines.length) {
            bodyStr += lines[i];
            if (i < lines.length - 1) {
                bodyStr += "\n";
            }
            i++;
        }
        // Add final newline before null terminator (part of the frame format)
        if (bodyStr.length() > 0) {
            bodyStr += "\n";
        }
        body = bodyStr;
    }

    @Override
    public String toString() {
        String str = "";
        str += type.toString() + "\n";
        for (int i = 0; i < headers.size(); i++) {
            Header header = headers.get(i);
            str += header.key + ":" + header.value + "\n";
        }
        str += body + "\n";
        str += "\0";

        return str;
    }


    public FrameType getType() {
        return type;
    }

    public String getBody() {
        return body;
    }

    public Vector<Header> getHeaders() {
        return headers;
    }

    public static class Header {
        private String key;
        private String value;

        public Header(String key, String value) {
            this.key = key;
            this.value = value;
        }

        public String getKey() {
            return key;
        }
        public String getValue() {
            return value;
        }
    }
    
    
}
