/*
this enum represents the different types of STOMP frames.
it contains both the commands sent by the client and the server responses.
*/

package bgu.spl.net.impl.stomp;

public enum FrameType {
    CONNECT,
    SEND,
    SUBSCRIBE,
    UNSUBSCRIBE,
    DISCONNECT,
    MESSAGE,
    RECEIPT,
    ERROR
}