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
    private boolean loggedIn = false;



    @Override
    public void start(int connectionId, Connections<StompFrame> connections) {
        this.connectionId = connectionId;
        this.connections = connections; 
    }
    

    @Override
    public void process(StompFrame message) {
        StompFrame.Header receiptHeader = message.getReceipt();
        StompFrame receipt = null; 
        if (receiptHeader != null) 
            receipt = generateReceipt(receiptHeader);   

        if (message.getType() == FrameType.DISCONNECT) {
            if (receiptHeader == null) {
                terminate(null, "didn't provide receipt-id for DISCONNECT", "");
            }

            connections.send(connectionId,receipt);
            connections.disconnect(connectionId);
            loggedIn = false;
            shouldTerminate = true;
        }

        if (message.getType() == FrameType.SEND) { // we need to send MESSAGE to all of the subs in the channel
            String dest = message.getHeaderValue("destination");
            if(dest == null || dest.isEmpty()) {
                terminate(receiptHeader, "No destination provided", "");  
                return; 
            }
                
            ConcurrentHashMap<Integer, String> subscribers = connections.getSubscribers(dest);

            if(subscribers.isEmpty() || connections.getSubscriptionId(connectionId, dest) == null) {
                terminate(receiptHeader, "THe user is nut subscribed to the channel", "");
                return;
            }
                
            MessageIdCounter.getAndIncrement();

            for(Integer connectionId : subscribers.keySet()){
                String subscriberId = subscribers.get(connectionId);

                Vector<StompFrame.Header> headers = new Vector<>();
                headers.add(new StompFrame.Header("subscription", subscriberId));
                headers.add(new StompFrame.Header("message-id", String.valueOf(MessageIdCounter)));
                headers.add(new StompFrame.Header("destination", dest));
            

            StompFrame frame = new StompFrame(FrameType.MESSAGE, message.getBody(), headers);

            try {
                connections.send(connectionId, frame);
            } catch(Exception e) {
                terminate(receiptHeader, "Couldn't send the message to one or more subscribers", "");
                return;
            }
        }

        }
        if (message.getType() == FrameType.CONNECT) {
            if(loggedIn == true) {
                connections.send(connectionId, generateError(receiptHeader, "”User already logged in”", ""));
                return;
            }

            String login = null;
            String passcode = null;

            Vector<StompFrame.Header> headers = message.getHeaders();
            for (StompFrame.Header header : headers) {
                if ("login".equals(header.getKey())) {
                    login = header.getValue();
                    if (passcode != null)
                        break;
                } else if ("passcode".equals(header.getKey())) {
                    passcode = header.getValue();
                    if (login != null)
                        break;
                }  
            }

            if (login == null || passcode == null) {
                StompFrame error = generateError(receiptHeader,"CONNECT frane with no login or passcode","");
                connections.disconnect(connectionId);
                connections.send(connectionId, error);
                return;
            }

            if (connections.validateUser(login, passcode) < 0) {
                StompFrame error = generateError(receiptHeader,"Wrong password","");
                connections.disconnect(connectionId);
                connections.send(connectionId, error);
                return;
            }
            loggedIn = true;

            Vector<StompFrame.Header> connectedHeaders = new Vector<>();
            connectedHeaders.add(new StompFrame.Header("version", "1.2"));
            connections.send(connectionId, new StompFrame(FrameType.CONNECTED, "", connectedHeaders));
        }

        if (message.getType() == FrameType.SUBSCRIBE) {
            // Handle SUBSCRIBE frame
            String dest = message.getHeaderValue ("destination");
            String subscriberId = message.getHeaderValue ("id");
            if(dest == null || dest.isEmpty() || subscriberId == null || subscriberId.isEmpty()) {
                terminate(receiptHeader, "Wrong format for SUBSCRIBE", "");
                return;
            }
                
            connections.subscribe(connectionId, dest, subscriberId);


        }
        if (message.getType() == FrameType.UNSUBSCRIBE) {
            // Handle UNSUBSCRIBE frame
            String subId = message.getHeaderValue("id");
            if (subId == null || subId.isEmpty()) 
                return;

            String dest = connections.getDestinationBySubId(connectionId, subId);
            if (dest == null || dest.isEmpty()) {
                terminate(receiptHeader, "Wrong format for UNSUBSCRIBE", "");
                return;
            }
            connections.unsubscribe(connectionId, dest);
        }

        if (receipt != null) {
            connections.send(connectionId, receipt);
        }
    }

	/**
     * @return true if the connection should be terminated
     */
    @Override
    public boolean shouldTerminate() {
        return shouldTerminate;
    }

    private void terminate(StompFrame.Header source, String message, String body) {
        connections.send(connectionId, generateError(source, message, body));
        connections.disconnect(connectionId);
        shouldTerminate = true;
        loggedIn = false;
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