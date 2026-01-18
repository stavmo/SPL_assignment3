package bgu.spl.net.impl.stomp;

import java.util.Vector;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import bgu.spl.net.api.StompMessagingProtocol;
import bgu.spl.net.srv.ConnectionHandler;
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
    

    //TODO: add ERROR frames for failures
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
            String login = null;
            String passcode = null;

            Vector<StompFrame.Header> headers = message.getHeaders();
            for (StompFrame.Header header : headers) {
                if (header.getKey() == "login") {
                    login = header.getValue();
                    if (passcode != null)
                        break;
                } else if (header.getKey() == "passcode") {
                    passcode = header.getValue();
                    if (login != null)
                        break;
                }  
            }

            StompFrame.Header receiptHeader = message.getReceipt();
            if (login == null || passcode == null) {
                StompFrame error = generateError(receiptHeader,"CONNECT frane with no login or passcode","");
                connections.disconnect(connectionId);
                connections.send(connectionId, error);
                return;
            }

            if (connections.validateUser(null, null) < 0) {
                StompFrame error = generateError(receiptHeader,"Wrong username or passcode, try again","");
                connections.disconnect(connectionId);
                connections.send(connectionId, error);
                return;
            }

            Vector<StompFrame.Header> connectedHeaders = new Vector<>();
            connectedHeaders.add(new StompFrame.Header("version", "1.2"));
            connections.send(connectionId, new StompFrame(FrameType.CONNECTED, "", connectedHeaders));

            if (receiptHeader != null) {
                Vector<StompFrame.Header> receiptHeaders = new Vector<>();
                connectedHeaders.add(receiptHeader);
                connections.send(connectionId, new StompFrame(FrameType.RECEIPT, "", receiptHeaders));
            }
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

            String subId = message.getHeaderValue("id");
            if (subId.isEmpty()) 
                return;

            String dest = connections.getDestinationBySubId(connectionId, subId);
            if (dest.isEmpty()) 
                return; // ADD ERROR HERE

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

    private StompFrame generateReceipt(int id) {
        Vector<StompFrame.Header> headers = new Vector<StompFrame.Header>();
        headers.add(new StompFrame.Header("Receipt-id", Integer.toString(id)));

        return new StompFrame(FrameType.RECEIPT, "", headers);
    }

    private StompFrame generateReceipt(StompFrame.Header id) {
        Vector<StompFrame.Header> headers = new Vector<StompFrame.Header>();
        headers.add(id);
        return new StompFrame(FrameType.RECEIPT, "", headers);
    }

    private StompFrame generateError(StompFrame.Header source, String message, String body) {
        Vector<StompFrame.Header> headers = new Vector<>();
        if (source != null) {
            headers.add(source);
        }
        StompFrame.Header msgHeader = new StompFrame.Header("message", message);
        headers.add(msgHeader);

        if (body == null) {
            body = "";
        }

        return new StompFrame(FrameType.ERROR, body, headers);
    }
}