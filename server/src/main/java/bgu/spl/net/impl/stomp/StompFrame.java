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
    final private String body; //can be an empty string or can have content.
    private boolean hasReceipt = false;


    public StompFrame(FrameType type, String body, Vector<Header> headers) {
        this.type = type;
        //this.body = body;
        this.body = (body == null) ? "" : body;
        this.headers = headers;
        for (Header header: headers) {
            if ("receipt-id".equals(header.getKey())) {
                hasReceipt = true;
            }
        }
    }


    //this constructor parses a raw frame string into a StompFrame object
    public StompFrame(String rawFrame) {
        // Remove trailing null terminator if present
        if (rawFrame.endsWith("\0")) {
            rawFrame = rawFrame.substring(0, rawFrame.length() - 1);
        }
        headers = new Vector<>();
        //String[] lines = rawFrame.split("\n");
        String[] lines = rawFrame.split("\n", -1);
        type = FrameType.valueOf(lines[0]);
        int i = 1;
       /*  while (i < lines.length && lines[i].contains(":")) {
            String[] keyValue = lines[i].split(":", 2);
            headers.add(new Header(keyValue[0], keyValue[1]));
            i++;
        }
        i++;
        String bodyStr = "";
        while (i < lines.length) {
            bodyStr += lines[i];
            if (i < lines.length - 1) {
                bodyStr += "\n";
            }
            if (i < lines.length && lines[i].isEmpty()) {
                i++;
            }
        }
        // Add final newline before null terminator (part of the frame format)
        if (bodyStr.length() > 0) {
            bodyStr += "\n";
        }
        body = bodyStr;
        
        // Check if any header is receipt-id
        for (Header header: headers) {
            if ("receipt-id".equals(header.getKey())) {
                hasReceipt = true;
                break;
            }
        } */

        while (i < lines.length && lines[i].contains(":")) {
            String[] keyValue = lines[i].split(":", 2);
            headers.add(new Header(keyValue[0], keyValue[1]));
            i++;
        }

        // skip exactly one empty line (the separator)

        if (i < lines.length && lines[i].isEmpty()) {
            i++;
        }

        StringBuilder bodySb = new StringBuilder();
        while (i < lines.length) {
            bodySb.append(lines[i]);
            if (i < lines.length - 1) bodySb.append("\n");
                i++;
        }

        body = bodySb.toString();
    }

    @Override
    public String toString() {
        /* String str = "";
        str += type.toString() + "\n";
        for (int i = 0; i < headers.size(); i++) {
            Header header = headers.get(i);
            str += header.key + ":" + header.value + "\n";
        }
        str += body + "\n";
        str += "\0";

        return str; */

        StringBuilder sb = new StringBuilder();

        // command line
        sb.append(type.toString()).append('\n');

        // headers
        for (Header h : headers) {
            sb.append(h.getKey()).append(':').append(h.getValue()).append('\n');
        }

        // blank line between headers and body
        sb.append('\n');

        // body (as-is)
        //if (body != null) {
        sb.append(body);
        //}

        return sb.toString();
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

  /*   public boolean hasReceipt() {
        return hasReceipt;
    } */

    public Header getReceipt() {
        //if (hasReceipt) {
        for (Header header : headers) {
            //if (header.key.equals("receipt-id"))
            if ("receipt".equals(header.getKey()))
                return header;
        }
        //}
        return null;
    }

    public String getHeaderValue(String key) {
        for (Header header : headers) {
            if (header.getKey().equals(key)) {
                return header.getValue();
            }
        }
        return "";
    }

    public static class Header {
        private final String key;
        private final String value;

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

    public void addHeader(Header h) {
        headers.add(h);
    }
    
}
