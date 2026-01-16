/*
this class represents a STOMP frame. a frame has a type, a body and a list of headers.
    each header is a key-value pair.
    the frame types are defined in the FrameType enum.

    :)

 */

package bgu.spl.net.impl.stomp;

import java.util.Vector;

public class StompFrame {
    FrameType type;
    Vector<Header> headers;
    String body;

    public StompFrame(FrameType type, String body, Vector<Header> headers) {
        this.type = type;
        this.body = body;
        this.headers = headers;
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

    class Header {
        String key;
        String value;

        public Header(String key, String value) {
            this.key = key;
            this.value = value;
        }
    }
    
    
}
