package app.aura.pilot;

import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URI;
import java.nio.charset.StandardCharsets;

final class AuraApi {
    static final class Failure extends Exception {
        final int status;
        Failure(int status, String message) { super(message); this.status = status; }
    }
    private final String origin;
    private final String token;
    AuraApi(String origin, String token) { this.origin = origin; this.token = token; }
    static String normalize(String input, boolean allowHTTP) {
        String value = input.trim().replaceAll("/+$", "");
        URI uri = URI.create(value);
        if (uri.getHost() == null || uri.getUserInfo() != null || uri.getQuery() != null || uri.getFragment() != null || !uri.getPath().isEmpty()
            || !("https".equals(uri.getScheme()) || (allowHTTP && "http".equals(uri.getScheme()))))
            throw new IllegalArgumentException("Enter a server origin without a path. Release builds require HTTPS.");
        return value;
    }
    JSONObject get(String path) throws Exception { return call("GET", path, null); }
    JSONObject post(String path, JSONObject body) throws Exception { return call("POST", path, body); }
    JSONObject call(String method, String path, JSONObject body) throws Exception {
        byte[] bytes = request(method, path, body, 32 * 1024 * 1024);
        return new JSONObject(new String(bytes, StandardCharsets.UTF_8));
    }
    byte[] media(String id) throws Exception {
        if (!id.matches("[A-Za-z0-9_-]{22}")) throw new IllegalArgumentException("Invalid media identifier");
        return request("GET", "/api/media/" + id, null, 21 * 1024 * 1024);
    }
    private byte[] request(String method, String path, JSONObject body, int maximum) throws Exception {
        HttpURLConnection connection = (HttpURLConnection) URI.create(origin + path).toURL().openConnection();
        connection.setRequestMethod(method); connection.setConnectTimeout(10000); connection.setReadTimeout(15000);
        connection.setInstanceFollowRedirects(false); connection.setRequestProperty("Accept", "application/json");
        if (token != null) connection.setRequestProperty("Authorization", "Bearer " + token);
        try {
            if (body != null) {
                byte[] encoded = body.toString().getBytes(StandardCharsets.UTF_8);
                connection.setDoOutput(true); connection.setRequestProperty("Content-Type", "application/json"); connection.setFixedLengthStreamingMode(encoded.length);
                try (var stream = connection.getOutputStream()) { stream.write(encoded); }
            }
            int status = connection.getResponseCode();
            InputStream stream = status >= 200 && status < 300 ? connection.getInputStream() : connection.getErrorStream();
            ByteArrayOutputStream result = new ByteArrayOutputStream();
            if (stream != null) try (stream) {
                byte[] buffer = new byte[8192]; int length;
                while ((length = stream.read(buffer)) != -1) {
                    if (result.size() + length > maximum) throw new Failure(413, "Server response exceeded the size limit.");
                    result.write(buffer, 0, length);
                }
            }
            if (status < 200 || status >= 300) {
                String message = "Server request failed (" + status + ").";
                try { message = new JSONObject(result.toString(StandardCharsets.UTF_8.name())).optString("error", message); } catch (Exception ignored) { }
                throw new Failure(status, message);
            }
            return result.toByteArray();
        } finally { connection.disconnect(); }
    }
    static JSONObject object(Object... values) {
        JSONObject result = new JSONObject();
        try { for (int i = 0; i < values.length; i += 2) result.put((String) values[i], values[i + 1]); }
        catch (Exception error) { throw new IllegalArgumentException(error); }
        return result;
    }
}
