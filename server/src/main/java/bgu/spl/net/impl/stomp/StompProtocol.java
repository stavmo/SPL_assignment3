package bgu.spl.net.impl.stomp;

import bgu.spl.net.api.StompMessagingProtocol;
import bgu.spl.net.srv.Connections;

public class StompProtocol implements StompMessagingProtocol<StompFrame> {

    private boolean shouldTerminate = false;
    private int connectionId = -1;
    private Connections<StompFrame> connections;

    @Override
    public void start(int connectionId, Connections<StompFrame> connections) {
        this.connectionId = connectionId;
        this.connections = connections; 
    }
    
    @Override
    public void process(StompFrame message) {
        if (message.getType() == FrameType.DISCONNECT) {
            shouldTerminate = true;
            //delete this line after testing    
            System.out.println("Connection " + connectionId + " disconnected.");
        }
        if (message.getType() == FrameType.SEND) {
            connections.send(connectionId, message);


            //delete this line after testing    
            System.out.println("Connection " + connectionId + " sent a message.");
        }
        if (message.getType() == FrameType.CONNECT) {
            // Handle CONNECT frame
            //TODO!!!!!

            //delete this line after testing
            System.out.println("Connection " + connectionId + " connected.");

        }
        if (message.getType() == FrameType.SUBSCRIBE) {
            // Handle SUBSCRIBE frame
            //TODO!!!!! 

            //delete this line after testing
            System.out.println("Connection " + connectionId + " subscribed.");

        }
        if (message.getType() == FrameType.UNSUBSCRIBE) {
            // Handle UNSUBSCRIBE frame
            //TODO!!!!!

            //delete this line after testing
            System.out.println("Connection " + connectionId + " unsubscribed.");
        }

    }



	/**
     * @return true if the connection should be terminated
     */
    @Override
    public boolean shouldTerminate() {
        return shouldTerminate;
    }
} 