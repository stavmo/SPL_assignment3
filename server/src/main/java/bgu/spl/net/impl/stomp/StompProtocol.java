package bgu.spl.net.impl.stomp;

import java.util.Vector;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import bgu.spl.net.api.StompMessagingProtocol;
import bgu.spl.net.srv.Connections;

public class StompProtocol implements StompMessagingProtocol<StompFrame> {

    private boolean shouldTerminate = false;
    private int connectionId = -1;
    private Connections<StompFrame> connections;
    private static final AtomicInteger MessageIdCounter = new AtomicInteger(0);

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
        if (message.getType() == FrameType.SEND) { // we need to send MESSAGE to all of the subs in the channel
            String dest = message.getHeaderValue("destination");
            if(dest == "")
                return;
            ConcurrentHashMap<Integer, String> subscribers = connections.getSubscribers(dest);
            if(subscribers.isEmpty())
                return;

            for(Integer connectionId : subscribers.keySet()){
                String subscriberId = subscribers.get(connectionId);

                Vector<StompFrame.Header> headers = new Vector<>();
                headers.add(new StompFrame.Header("subscription", subscriberId));
                headers.add(new StompFrame.Header("message-id", String.valueOf(MessageIdCounter.getAndIncrement())));
                headers.add(new StompFrame.Header("destination", dest));
            

            StompFrame frame = new StompFrame(FrameType.MESSAGE, message.getBody(), headers);
            connections.send(connectionId, frame);
            }


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

            String dest = message.getHeaderValue ("destination");
            String subscriberId = message.getHeaderValue ("id");
            if(dest.isEmpty() | subscriberId.isEmpty())
                return;
            connections.subscribe(connectionId, dest, subscriberId);

            //delete this line after testing
            System.out.println("Connection " + connectionId + " subscribed.");

        }
        if (message.getType() == FrameType.UNSUBSCRIBE) {
            // Handle UNSUBSCRIBE frame

            String dest = message.getHeaderValue ("destination");
            String subscriberId = message.getHeaderValue ("id");
            if(subscriberId.isEmpty())
                return;
            connections.unsubscribe(connectionId, dest);

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