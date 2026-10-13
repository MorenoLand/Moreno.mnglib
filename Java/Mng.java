package mng;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public final class Mng {
    private static final byte[] MNG_SIGNATURE = {(byte) 0x8a, 0x4d, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a};
    private static final byte[] PNG_SIGNATURE = {(byte) 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a};

    public static final class Frame {
        public final byte[] png;
        public final long delayMilliseconds;

        public Frame(byte[] png, long delayMilliseconds) {
            this.png = png;
            this.delayMilliseconds = delayMilliseconds;
        }
    }

    public static final class Animation {
        public final long width;
        public final long height;
        public final long ticksPerSecond;
        public final long nominalLayerCount;
        public final long nominalFrameCount;
        public final long nominalPlayTime;
        public final long simplicityProfile;
        public final List<Frame> frames;

        private Animation(long width, long height, long ticksPerSecond, long nominalLayerCount, long nominalFrameCount, long nominalPlayTime, long simplicityProfile, List<Frame> frames) {
            this.width = width;
            this.height = height;
            this.ticksPerSecond = ticksPerSecond;
            this.nominalLayerCount = nominalLayerCount;
            this.nominalFrameCount = nominalFrameCount;
            this.nominalPlayTime = nominalPlayTime;
            this.simplicityProfile = simplicityProfile;
            this.frames = Collections.unmodifiableList(frames);
        }

        public int frameIndexAt(Duration elapsed) {
            if (frames.isEmpty()) return -1;
            if (frames.size() == 1) return 0;
            long duration = 0;
            for (Frame frame : frames) duration = duration > Long.MAX_VALUE - frame.delayMilliseconds ? Long.MAX_VALUE : duration + frame.delayMilliseconds;
            if (duration <= 0) return 0;
            long seconds = elapsed.getSeconds();
            long milliseconds = (seconds > Long.MAX_VALUE / 1000 ? Long.MAX_VALUE : seconds < Long.MIN_VALUE / 1000 ? Long.MIN_VALUE : elapsed.toMillis()) % duration;
            if (milliseconds < 0) milliseconds += duration;
            for (int index = 0; index < frames.size(); index++) {
                if (milliseconds < frames.get(index).delayMilliseconds) return index;
                milliseconds -= frames.get(index).delayMilliseconds;
            }
            return frames.size() - 1;
        }
    }

    public static final class ParseException extends Exception {
        public ParseException(String message) {
            super(message);
        }
    }

    private Mng() {
    }

    public static boolean isMng(byte[] data) {
        if (data == null || data.length < MNG_SIGNATURE.length) return false;
        for (int index = 0; index < MNG_SIGNATURE.length; index++) if (data[index] != MNG_SIGNATURE[index]) return false;
        return true;
    }

    public static Animation parse(byte[] data) throws ParseException {
        if (!isMng(data)) throw new ParseException("not an MNG image");
        long width = 0;
        long height = 0;
        long ticksPerSecond = 100;
        long nominalLayerCount = 0;
        long nominalFrameCount = 0;
        long nominalPlayTime = 0;
        long simplicityProfile = 0;
        List<Frame> frames = new ArrayList<>();
        ByteArray frame = new ByteArray();
        Long defaultTicks = null;
        Long nextTicks = null;
        boolean inPng = false;
        int offset = MNG_SIGNATURE.length;
        while (offset < data.length) {
            if (data.length - offset < 12) throw new ParseException("truncated MNG chunk");
            long dataLength = readU32(data, offset);
            long chunkLength = dataLength + 12;
            if (chunkLength < 12 || chunkLength > data.length - offset) throw new ParseException("invalid MNG chunk length");
            String type = new String(data, offset + 4, 4, java.nio.charset.StandardCharsets.US_ASCII);
            if (type.equals("MHDR")) {
                if (dataLength < 28) throw new ParseException("invalid MNG header");
                width = readU32(data, offset + 8);
                height = readU32(data, offset + 12);
                long ticks = readU32(data, offset + 16);
                if (ticks > 0) ticksPerSecond = ticks;
                nominalLayerCount = readU32(data, offset + 20);
                nominalFrameCount = readU32(data, offset + 24);
                nominalPlayTime = readU32(data, offset + 28);
                simplicityProfile = readU32(data, offset + 32);
            } else if (type.equals("FRAM")) {
                long[] change = parseFrameDelay(data, offset + 8, (int) dataLength);
                if (change != null && change[0] == 1) {
                    nextTicks = change[1];
                } else if (change != null && change[0] == 2) {
                    defaultTicks = change[1];
                    nextTicks = null;
                }
            }
            if (!inPng && type.equals("IHDR")) {
                frame.write(PNG_SIGNATURE);
                inPng = true;
            }
            if (inPng) {
                frame.write(data, offset, (int) chunkLength);
                if (type.equals("IEND")) {
                    Long ticks = nextTicks != null ? nextTicks : defaultTicks;
                    long delay = ticks == null ? 100 : Math.min(0xffffffffL, (ticks * 1000 + ticksPerSecond / 2) / ticksPerSecond);
                    frames.add(new Frame(frame.toByteArray(), delay));
                    frame.clear();
                    nextTicks = null;
                    inPng = false;
                }
            }
            offset += (int) chunkLength;
        }
        if (inPng || frames.isEmpty()) throw new ParseException("MNG contains no complete frames");
        return new Animation(width, height, ticksPerSecond, nominalLayerCount, nominalFrameCount, nominalPlayTime, simplicityProfile, frames);
    }

    public static byte[] firstPngFrame(byte[] data) throws ParseException {
        return parse(data).frames.get(0).png.clone();
    }

    private static long readU32(byte[] data, int offset) {
        return ((long) (data[offset] & 0xff) << 24) | ((long) (data[offset + 1] & 0xff) << 16) | ((long) (data[offset + 2] & 0xff) << 8) | (data[offset + 3] & 0xffL);
    }

    private static long[] parseFrameDelay(byte[] data, int offset, int length) {
        if (length == 0) return null;
        int index = 1;
        while (index < length && data[offset + index] != 0) index++;
        if (index == length) return null;
        index++;
        if (index >= length) return null;
        int change = data[offset + index++] & 0xff;
        if (length - index < 3) return null;
        index += 3;
        if (change == 0 || length - index < 4) return null;
        return new long[] {change, readU32(data, offset + index)};
    }

    private static final class ByteArray {
        private byte[] data = new byte[64];
        private int size;

        void write(byte[] source) throws ParseException {
            write(source, 0, source.length);
        }

        void write(byte[] source, int offset, int length) throws ParseException {
            ensure((long) size + length);
            System.arraycopy(source, offset, data, size, length);
            size += length;
        }

        byte[] toByteArray() {
            byte[] result = new byte[size];
            System.arraycopy(data, 0, result, 0, size);
            return result;
        }

        void clear() {
            size = 0;
        }

        private void ensure(long required) throws ParseException {
            if (required <= data.length) return;
            if (required > Integer.MAX_VALUE - 8) throw new ParseException("MNG frame too large");
            long capacity = data.length;
            while (capacity < required) capacity *= 2;
            byte[] resized = new byte[(int) Math.min(capacity, Integer.MAX_VALUE - 8)];
            System.arraycopy(data, 0, resized, 0, size);
            data = resized;
        }
    }
}
