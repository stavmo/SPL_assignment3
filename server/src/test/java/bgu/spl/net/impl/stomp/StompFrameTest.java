package bgu.spl.net.impl.stomp;

import java.util.Vector;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import org.junit.jupiter.api.Test;

public class StompFrameTest {

    private Vector<StompFrame.Header> createTestHeaders() {
        Vector<StompFrame.Header> headers = new Vector<>();
        headers.add(new StompFrame.Header("accept-version", "1.2"));
        headers.add(new StompFrame.Header("host", "localhost"));
        return headers;
    }

    @Test
    public void testStompFrameConstructorWithParameters() {
        Vector<StompFrame.Header> headers = createTestHeaders();
        StompFrame frame = new StompFrame(FrameType.CONNECT, "body content", headers);
        
        assertEquals(FrameType.CONNECT, frame.getType());
        assertEquals("body content", frame.getBody());
        assertEquals(2, frame.getHeaders().size());
        assertEquals("accept-version", frame.getHeaders().get(0).getKey());
        assertEquals("1.2", frame.getHeaders().get(0).getValue());
    }

    @Test
    public void testStompFrameConstructorWithEmptyBody() {
        Vector<StompFrame.Header> headers = createTestHeaders();
        StompFrame frame = new StompFrame(FrameType.DISCONNECT, "", headers);
        
        assertEquals(FrameType.DISCONNECT, frame.getType());
        assertEquals("", frame.getBody());
        assertEquals(2, frame.getHeaders().size());
    }

    @Test
    public void testStompFrameConstructorWithNullHeaders() {
        Vector<StompFrame.Header> emptyHeaders = new Vector<>();
        StompFrame frame = new StompFrame(FrameType.SEND, "test body", emptyHeaders);
        
        assertEquals(FrameType.SEND, frame.getType());
        assertEquals("test body", frame.getBody());
        assertEquals(0, frame.getHeaders().size());
    }

    @Test
    public void testStompFrameParsingFromString() {
        String rawFrame = "CONNECT\n" +
                          "accept-version:1.2\n" +
                          "host:localhost\n" +
                          "\n" +
                          "body content\n" +
                          "\0";
        
        StompFrame frame = new StompFrame(rawFrame);
        
        assertEquals(FrameType.CONNECT, frame.getType());
        assertEquals(2, frame.getHeaders().size());
        assertEquals("\nbody content\n", frame.getBody());
    }

    @Test
    public void testStompFrameParsingWithMultiLineBody() {
        String rawFrame = "MESSAGE\n" +
                          "subscription:0\n" +
                          "message-id:123\n" +
                          "\n" +
                          "line1\n" +
                          "line2\n" +
                          "line3\n" +
                          "\0";
        
        StompFrame frame = new StompFrame(rawFrame);
        
        assertEquals(FrameType.MESSAGE, frame.getType());
        assertEquals(2, frame.getHeaders().size());
        assertEquals("\nline1\nline2\nline3\n", frame.getBody());
    }

    @Test
    public void testStompFrameParsingWithNoBody() {
        String rawFrame = "DISCONNECT\n" +
                          "receipt-id:123\n" +
                          "\n" +
                          "\n" +
                          "\0";
        
        StompFrame frame = new StompFrame(rawFrame);
        
        assertEquals(FrameType.DISCONNECT, frame.getType());
        assertEquals(1, frame.getHeaders().size());
        assertEquals("receipt-id", frame.getHeaders().get(0).getKey());
        assertEquals("123", frame.getHeaders().get(0).getValue());
    }

    @Test
    public void testStompFrameParsingWithNoHeaders() {
        String rawFrame = "SEND\n" +
                          "\n" +
                          "just body\n" +
                          "\0";
        
        StompFrame frame = new StompFrame(rawFrame);
        
        assertEquals(FrameType.SEND, frame.getType());
        assertEquals(0, frame.getHeaders().size());
        assertEquals("\njust body\n", frame.getBody());
    }

    @Test
    public void testToStringMethod() {
        Vector<StompFrame.Header> headers = createTestHeaders();
        StompFrame frame = new StompFrame(FrameType.CONNECT, "body", headers);
        String result = frame.toString();
        
        assertTrue(result.startsWith("CONNECT\n"));
        assertTrue(result.contains("accept-version:1.2\n"));
        assertTrue(result.contains("host:localhost\n"));
        assertTrue(result.contains("body\n"));
        assertTrue(result.endsWith("\0"));
    }

    @Test
    public void testToStringRoundTrip() {
        Vector<StompFrame.Header> headers = createTestHeaders();
        StompFrame originalFrame = new StompFrame(FrameType.MESSAGE, "test body", headers);
        String frameString = originalFrame.toString();
        StompFrame parsedFrame = new StompFrame(frameString);
        
        assertEquals(originalFrame.getType(), parsedFrame.getType());
        assertEquals(originalFrame.getBody() + "\n", parsedFrame.getBody());
        assertEquals(originalFrame.getHeaders().size(), parsedFrame.getHeaders().size());
    }

    @Test
    public void testHeaderGetters() {
        StompFrame.Header header1 = new StompFrame.Header("accept-version", "1.2");
        StompFrame.Header header2 = new StompFrame.Header("host", "localhost");
        
        assertEquals("accept-version", header1.getKey());
        assertEquals("1.2", header1.getValue());
        assertEquals("host", header2.getKey());
        assertEquals("localhost", header2.getValue());
    }

    @Test
    public void testFrameGetters() {
        Vector<StompFrame.Header> testHeaders = new Vector<>();
        testHeaders.add(new StompFrame.Header("key1", "value1"));
        StompFrame frame = new StompFrame(FrameType.SUBSCRIBE, "body", testHeaders);
        
        assertNotNull(frame.getType());
        assertNotNull(frame.getBody());
        assertNotNull(frame.getHeaders());
        assertEquals(FrameType.SUBSCRIBE, frame.getType());
    }

    @Test
    public void testDifferentFrameTypes() {
        Vector<StompFrame.Header> headers = createTestHeaders();
        for (FrameType type : FrameType.values()) {
            StompFrame frame = new StompFrame(type, "body", headers);
            assertEquals(type, frame.getType());
        }
    }

    @Test
    public void testHeaderWithSpecialCharacters() {
        StompFrame.Header header = new StompFrame.Header("key-with-dash", "value:with:colons");
        assertEquals("key-with-dash", header.getKey());
        assertEquals("value:with:colons", header.getValue());
    }

    @Test
    public void testBodyWithSpecialCharacters() {
        String specialBody = "Line1\nLine2\t\tTabbed\nLine3!@#$%";
        StompFrame frame = new StompFrame(FrameType.ERROR, specialBody, new Vector<>());
        
        assertEquals(specialBody, frame.getBody());
    }

    @Test
    public void testParsingFrameWithHeaderColonInValue() {
        String rawFrame = "SEND\n" +
                          "destination:/topic/test:123\n" +
                          "content-type:application/json\n" +
                          "\n" +
                          "{\"key\": \"value\"}\n" +
                          "\0";
        
        StompFrame frame = new StompFrame(rawFrame);
        
        assertEquals(FrameType.SEND, frame.getType());
        assertEquals(2, frame.getHeaders().size());
        assertEquals("/topic/test:123", frame.getHeaders().get(0).getValue());
    }

    @Test
    public void testEmptyFrame() {
        Vector<StompFrame.Header> emptyHeaders = new Vector<>();
        StompFrame frame = new StompFrame(FrameType.RECEIPT, "", emptyHeaders);
        
        assertEquals(FrameType.RECEIPT, frame.getType());
        assertEquals("", frame.getBody());
        assertTrue(frame.getHeaders().isEmpty());
    }
}