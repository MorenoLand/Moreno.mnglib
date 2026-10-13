using System;
using System.Collections.Generic;

namespace Mng
{
    public sealed class MngFrame
    {
        public MngFrame(byte[] png, uint delayMilliseconds)
        {
            Png = png;
            DelayMilliseconds = delayMilliseconds;
        }

        public byte[] Png { get; }
        public uint DelayMilliseconds { get; }
    }

    public sealed class MngAnimation
    {
        public uint Width { get; internal set; }
        public uint Height { get; internal set; }
        public uint TicksPerSecond { get; internal set; } = 100;
        public uint NominalLayerCount { get; internal set; }
        public uint NominalFrameCount { get; internal set; }
        public uint NominalPlayTime { get; internal set; }
        public uint SimplicityProfile { get; internal set; }
        public IList<MngFrame> Frames { get; } = new List<MngFrame>();

        public int FrameIndexAt(TimeSpan elapsed)
        {
            if (Frames.Count == 0) return -1;
            if (Frames.Count == 1) return 0;
            long duration = 0;
            foreach (MngFrame frame in Frames) duration += frame.DelayMilliseconds;
            if (duration <= 0) return 0;
            long milliseconds = (long)elapsed.TotalMilliseconds % duration;
            if (milliseconds < 0) milliseconds += duration;
            for (int index = 0; index < Frames.Count; index++)
            {
                if (milliseconds < Frames[index].DelayMilliseconds) return index;
                milliseconds -= Frames[index].DelayMilliseconds;
            }
            return Frames.Count - 1;
        }
    }

    public static class MngParser
    {
        private static readonly byte[] MngSignature = { 0x8a, 0x4d, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a };
        private static readonly byte[] PngSignature = { 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a };

        public static bool IsMng(byte[] data)
        {
            if (data == null || data.Length < MngSignature.Length) return false;
            for (int index = 0; index < MngSignature.Length; index++) if (data[index] != MngSignature[index]) return false;
            return true;
        }

        public static MngAnimation Parse(byte[] data)
        {
            if (!IsMng(data)) throw new FormatException("not an MNG image");
            var animation = new MngAnimation();
            var frame = new List<byte>();
            uint defaultTicks = 0;
            bool hasDefaultTicks = false;
            uint nextTicks = 0;
            bool hasNextTicks = false;
            bool inPng = false;
            int offset = MngSignature.Length;
            while (offset < data.Length)
            {
                if (data.Length - offset < 12) throw new FormatException("truncated MNG chunk");
                ulong dataLength = ReadU32(data, offset);
                ulong chunkLength = dataLength + 12;
                if (chunkLength < 12 || chunkLength > (ulong)(data.Length - offset)) throw new FormatException("invalid MNG chunk length");
                int length = (int)dataLength;
                string type = System.Text.Encoding.ASCII.GetString(data, offset + 4, 4);
                if (type == "MHDR")
                {
                    if (length < 28) throw new FormatException("invalid MNG header");
                    animation.Width = ReadU32(data, offset + 8);
                    animation.Height = ReadU32(data, offset + 12);
                    uint ticks = ReadU32(data, offset + 16);
                    if (ticks > 0) animation.TicksPerSecond = ticks;
                    animation.NominalLayerCount = ReadU32(data, offset + 20);
                    animation.NominalFrameCount = ReadU32(data, offset + 24);
                    animation.NominalPlayTime = ReadU32(data, offset + 28);
                    animation.SimplicityProfile = ReadU32(data, offset + 32);
                }
                else if (type == "FRAM" && ParseFrameDelay(data, offset + 8, length, out byte change, out uint ticks))
                {
                    if (change == 1)
                    {
                        nextTicks = ticks;
                        hasNextTicks = true;
                    }
                    else if (change == 2)
                    {
                        defaultTicks = ticks;
                        hasDefaultTicks = true;
                        hasNextTicks = false;
                    }
                }
                if (!inPng && type == "IHDR")
                {
                    frame.AddRange(PngSignature);
                    inPng = true;
                }
                if (inPng)
                {
                    for (int index = 0; index < (int)chunkLength; index++) frame.Add(data[offset + index]);
                    if (type == "IEND")
                    {
                        uint delay = 100;
                        if (hasNextTicks || hasDefaultTicks)
                        {
                            ulong milliseconds = ((ulong)(hasNextTicks ? nextTicks : defaultTicks) * 1000 + animation.TicksPerSecond / 2) / animation.TicksPerSecond;
                            delay = milliseconds > uint.MaxValue ? uint.MaxValue : (uint)milliseconds;
                        }
                        animation.Frames.Add(new MngFrame(frame.ToArray(), delay));
                        frame.Clear();
                        hasNextTicks = false;
                        inPng = false;
                    }
                }
                offset += (int)chunkLength;
            }
            if (inPng || animation.Frames.Count == 0) throw new FormatException("MNG contains no complete frames");
            return animation;
        }

        public static byte[] FirstPngFrame(byte[] data)
        {
            return (byte[])Parse(data).Frames[0].Png.Clone();
        }

        private static uint ReadU32(byte[] data, int offset)
        {
            return ((uint)data[offset] << 24) | ((uint)data[offset + 1] << 16) | ((uint)data[offset + 2] << 8) | data[offset + 3];
        }

        private static bool ParseFrameDelay(byte[] data, int offset, int length, out byte change, out uint delay)
        {
            change = 0;
            delay = 0;
            if (length == 0) return false;
            int index = 1;
            while (index < length && data[offset + index] != 0) index++;
            if (index == length) return false;
            index++;
            if (index >= length) return false;
            change = data[offset + index++];
            if (length - index < 3) return false;
            index += 3;
            if (change == 0 || length - index < 4) return false;
            delay = ReadU32(data, offset + index);
            return true;
        }
    }
}
