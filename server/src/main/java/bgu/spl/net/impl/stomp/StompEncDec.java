package bgu.spl.net.impl.stomp;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;

import bgu.spl.net.api.MessageEncoderDecoder;

public class StompEncDec implements MessageEncoderDecoder<StompFrame> {

    private static final byte TERMINATOR = '\0';
    private final ByteArrayOutputStream buffer = new ByteArrayOutputStream();

    /**
     * Accumulate bytes until the STOMP frame terminator (\0) is seen, then parse.
     */
    public StompFrame decodeNextByte(byte nextByte) {
        if (nextByte == TERMINATOR) {
         //   String raw = buffer.toString(StandardCharsets.UTF_8);
         //   buffer.reset();
         //   return new StompFrame(raw + "\0");
        }

        buffer.write(nextByte);
        return null;
    }

    /**
     * Encode a frame using UTF-8.
     */
    public byte[] encode(StompFrame message) {
        return message.toString().getBytes(StandardCharsets.UTF_8);
    }
}
