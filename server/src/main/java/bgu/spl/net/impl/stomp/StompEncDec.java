package bgu.spl.net.impl.stomp;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;

import bgu.spl.net.api.MessageEncoderDecoder;

public class StompEncDec implements MessageEncoderDecoder<StompFrame> {

    private static final byte TERMINATOR = '\0';
    private byte[] bytes = new byte[1 << 10]; //start with 1k
    private int len = 0;


    /**
     * Accumulate bytes until the STOMP frame terminator (\0) is seen, then parse.
     */
    public StompFrame decodeNextByte(byte nextByte) {
        if (nextByte == TERMINATOR) {
           return popFrame();
        }

        pushByte(nextByte);
        return null;
    }

    /**
     * Encode a frame using UTF-8.
     */
    public byte[] encode(StompFrame message) {
        return message.toString().getBytes();
    }

    private void pushByte(byte nextByte) {
        if (len >= bytes.length) {
            bytes = Arrays.copyOf(bytes, len * 2);
        }

        bytes[len++] = nextByte;
    }

        private StompFrame popFrame() {
        //notice that we explicitly requesting that the string will be decoded from UTF-8
        //this is not actually required as it is the default encoding in java.
        String resultS = new String(bytes, 0, len, StandardCharsets.UTF_8);
        len = 0;
        return new StompFrame(resultS);
    }
}
