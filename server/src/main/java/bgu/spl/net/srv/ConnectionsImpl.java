package bgu.spl.net.srv;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import bgu.spl.net.impl.stomp.StompFrame;

public class ConnectionsImpl<T> implements Connections<T> {

    private final ConcurrentHashMap<String, String> users = new ConcurrentHashMap<>();
    
    private final ConcurrentHashMap<Integer, ConnectionHandler<T>> handlers = new ConcurrentHashMap<>();

    //private final ConcurrentHashMap<String, Set<Integer>> channelSubscribers = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, ConcurrentHashMap<Integer, String>> channelSubscribers = new ConcurrentHashMap<>();

    //private final ConcurrentHashMap<Integer, Set<String>> subscriptionsById = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<Integer, ConcurrentHashMap<String, String>> subscriptionsById = new ConcurrentHashMap<>();

    public void connect(int connectionId, ConnectionHandler<T> handler) {
        handlers.put(connectionId, handler);
        subscriptionsById.putIfAbsent(connectionId, new ConcurrentHashMap<>());
    }

    @Override
    public boolean send(int connectionId, T msg) {
        ConnectionHandler<T> h = handlers.get(connectionId);
        if (h == null) 
            return false;

        h.send(msg);
        return true;
    }

    @Override
    public void send(String channel, T msg) {
        ConcurrentHashMap<Integer, String> subs = channelSubscribers.get(channel);
        if (subs == null) return;

        // send to all the users that are currently subscribed
        for (Integer id : subs.keySet()) {

            send(id, msg);
        }
    }

    @Override
    public void disconnect(int connectionId) {
    
        ConcurrentHashMap<String, String> mySubs = subscriptionsById.remove(connectionId);
        if (mySubs == null) 
            return;

        // remove from all channels
        for (String dest : mySubs.keySet()) {
            ConcurrentHashMap<Integer, String> subs = channelSubscribers.get(dest);
            if (subs != null) {
                subs.remove(connectionId);
                if (subs.isEmpty()) {
                    channelSubscribers.remove(dest, subs);
                }
            }
        }
    }
    

   
     public void subscribe(int connectionId, String destination, String subscriptionId) {
        subscriptionsById.putIfAbsent(connectionId, new ConcurrentHashMap<>());
        subscriptionsById.get(connectionId).put(destination, subscriptionId);

        channelSubscribers.putIfAbsent(destination, new ConcurrentHashMap<>());
        channelSubscribers.get(destination).put(connectionId, subscriptionId);
    }

    public void unsubscribe(int connectionId, String destination) {
        ConcurrentHashMap<String, String> my = subscriptionsById.get(connectionId);
        if (my != null) {
            my.remove(destination);
        }

        ConcurrentHashMap<Integer, String> subs = channelSubscribers.get(destination);
        if (subs != null) {
            subs.remove(connectionId);
            if (subs.isEmpty()) {
                channelSubscribers.remove(destination, subs);
            }
        }
    }




    //HELPERS
    public ConcurrentHashMap<Integer, String> getSubscribers(String destination) {
        ConcurrentHashMap<Integer, String> m = channelSubscribers.get(destination);
        return (m == null) ? new ConcurrentHashMap<>() : m;
    }

    public String getSubscriptionId(int connectionId, String destination) {
        Map<String, String> my = subscriptionsById.get(connectionId);
        if (my == null)
            return null;
        return my.get(destination);
    }

    public String getDestinationBySubId(int connectionId, String subId) {
        ConcurrentHashMap<String, String> my = subscriptionsById.get(connectionId);
        if (my == null) return null;

        for (Map.Entry<String, String> e : my.entrySet()) {
            if (subId.equals(e.getValue())) {
                return e.getKey(); // destination
            }
        }
        return null;
    }

    public ConnectionHandler<T> getHandlerByID(int connectionId) {
        return handlers.get(connectionId);
    }


    //returns 0 if old user and right password.
    //returns 1 if new user and adds the user to the dataBase
    //returns -1 if wrong password,
    public int validateUser(String login, String password) {
        String pass = users.get(login);
        if (pass == null) {
            users.put(login, password);
            return 1;
        }

        if (pass.equals(password)) {
            return 0;
        }

        return -1;
    }
}

