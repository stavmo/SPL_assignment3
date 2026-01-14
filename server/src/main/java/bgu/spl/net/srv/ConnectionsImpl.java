package bgu.spl.net.srv;

import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

public class ConnectionsImpl<T> implements Connections<T> {

    
    private final ConcurrentHashMap<Integer, ConnectionHandler<T>> handlers = new ConcurrentHashMap<>();

    private final ConcurrentHashMap<String, Set<Integer>> channelSubscribers = new ConcurrentHashMap<>();

    private final ConcurrentHashMap<Integer, Set<String>> subscriptionsById = new ConcurrentHashMap<>();

    public void connect(int connectionId, ConnectionHandler<T> handler) {
        handlers.put(connectionId, handler);
        subscriptionsById.putIfAbsent(connectionId, ConcurrentHashMap.newKeySet());
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
        Set<Integer> subs = channelSubscribers.get(channel);
        if (subs == null) return;

        // send to all the users that are currently subscribed
        for (Integer id : subs) {
            send(id, msg);
        }
    }

    @Override
    public void disconnect(int connectionId) {
    
        handlers.remove(connectionId);

        // remove from all channels
        Set<String> channels = subscriptionsById.remove(connectionId);
        if (channels != null) {
            for (String ch : channels) {
                Set<Integer> subs = channelSubscribers.get(ch);
                if (subs != null) {
                    subs.remove(connectionId);
                    if (subs.isEmpty()) {
                        channelSubscribers.remove(ch, subs);
                    }
                }
            }
        }
    }

   
    public void subscribe(int connectionId, String channel) {
        subscriptionsById.putIfAbsent(connectionId, ConcurrentHashMap.newKeySet());
        subscriptionsById.get(connectionId).add(channel);

        channelSubscribers.putIfAbsent(channel, ConcurrentHashMap.newKeySet());
        channelSubscribers.get(channel).add(connectionId);
    }

    public void unsubscribe(int connectionId, String channel) {
        Set<String> my = subscriptionsById.get(connectionId);
        if (my != null) 
            my.remove(channel);

        Set<Integer> subs = channelSubscribers.get(channel);
        if (subs != null) {
            subs.remove(connectionId);
            if (subs.isEmpty()) {
                channelSubscribers.remove(channel, subs);
            }
        }

}
}
