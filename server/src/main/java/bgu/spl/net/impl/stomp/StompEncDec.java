package bgu.spl.net.impl.stomp;

import bgu.spl.net.api.MessageEncoderDecoder;

public class StompEncDec implements MessageEncoderDecoder<StompFrame> {

    public StompEncDec() {

    }


        /**
     * add the next byte to the decoding process
     *
     * @param nextByte the next byte to consider for the currently decoded
     * message
     * @return a message if this byte completes one or null if it doesnt.
     */
    public StompFrame decodeNextByte(byte nextByte) {
        return null; //place holder
    }

    /**
     * encodes the given message to bytes array
     *
     * @param message the message to encode
     * @return the encoded bytes
     */
    public byte[] encode(StompFrame message) {
        return null; //place holder
    }




    
}
