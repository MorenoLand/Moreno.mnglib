package tmng

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"math"
	"time"
)

var tMNGSignature = [...]byte{0x8a, 0x4d, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a}
var tPNGSignature = [...]byte{0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a}

type TMNGFrame struct {
	PNG   []byte
	Delay time.Duration
}

type TMNGAnimation struct {
	Width             uint32
	Height            uint32
	TicksPerSecond    uint32
	NominalLayerCount uint32
	NominalFrameCount uint32
	NominalPlayTime   uint32
	SimplicityProfile uint32
	Frames            []TMNGFrame
}

func IsMNG(data []byte) bool {
	return len(data) >= len(tMNGSignature) && bytes.Equal(data[:len(tMNGSignature)], tMNGSignature[:])
}

func tMNGFrameDelay(data []byte) (byte, uint32) {
	if len(data) == 0 {
		return 0, 0
	}
	offset := 1
	for offset < len(data) && data[offset] != 0 {
		offset++
	}
	offset++
	if offset >= len(data) {
		return 0, 0
	}
	change := data[offset]
	offset += 4
	if change == 0 || len(data)-offset < 4 {
		return 0, 0
	}
	return change, binary.BigEndian.Uint32(data[offset : offset+4])
}

func ParseMNG(data []byte) (*TMNGAnimation, error) {
	if !IsMNG(data) {
		return nil, fmt.Errorf("not an MNG image")
	}
	animation := &TMNGAnimation{TicksPerSecond: 100}
	var frame []byte
	var defaultTicks, nextTicks uint32
	hasDefaultTicks, hasNextTicks := false, false
	inPNG := false
	for offset := len(tMNGSignature); offset < len(data); {
		if len(data)-offset < 12 {
			return nil, fmt.Errorf("truncated MNG chunk")
		}
		dataLength := binary.BigEndian.Uint32(data[offset : offset+4])
		if uint64(dataLength) > uint64(len(data)-offset-12) {
			return nil, fmt.Errorf("invalid MNG chunk length")
		}
		chunkLength := int(dataLength) + 12
		chunkType := string(data[offset+4 : offset+8])
		chunkData := data[offset+8 : offset+8+int(dataLength)]
		switch chunkType {
		case "MHDR":
			if len(chunkData) < 28 {
				return nil, fmt.Errorf("invalid MNG header")
			}
			animation.Width = binary.BigEndian.Uint32(chunkData[0:4])
			animation.Height = binary.BigEndian.Uint32(chunkData[4:8])
			if ticks := binary.BigEndian.Uint32(chunkData[8:12]); ticks > 0 {
				animation.TicksPerSecond = ticks
			}
			animation.NominalLayerCount = binary.BigEndian.Uint32(chunkData[12:16])
			animation.NominalFrameCount = binary.BigEndian.Uint32(chunkData[16:20])
			animation.NominalPlayTime = binary.BigEndian.Uint32(chunkData[20:24])
			animation.SimplicityProfile = binary.BigEndian.Uint32(chunkData[24:28])
		case "FRAM":
			switch change, ticks := tMNGFrameDelay(chunkData); change {
			case 1:
				nextTicks, hasNextTicks = ticks, true
			case 2:
				defaultTicks, hasDefaultTicks, hasNextTicks = ticks, true, false
			}
		}
		if !inPNG && chunkType == "IHDR" {
			frame = append(frame[:0], tPNGSignature[:]...)
			inPNG = true
		}
		if inPNG {
			frame = append(frame, data[offset:offset+chunkLength]...)
			if chunkType == "IEND" {
				delay := 100 * time.Millisecond
				if hasNextTicks || hasDefaultTicks {
					ticks := defaultTicks
					if hasNextTicks {
						ticks = nextTicks
					}
					milliseconds := (uint64(ticks)*1000 + uint64(animation.TicksPerSecond)/2) / uint64(animation.TicksPerSecond)
					if milliseconds > math.MaxUint32 {
						milliseconds = math.MaxUint32
					}
					delay = time.Duration(milliseconds) * time.Millisecond
				}
				animation.Frames = append(animation.Frames, TMNGFrame{PNG: append([]byte(nil), frame...), Delay: delay})
				frame = frame[:0]
				hasNextTicks = false
				inPNG = false
			}
		}
		offset += chunkLength
	}
	if inPNG || len(animation.Frames) == 0 {
		return nil, fmt.Errorf("MNG contains no complete frames")
	}
	return animation, nil
}

func (animation *TMNGAnimation) FrameIndexAt(elapsed time.Duration) int {
	if animation == nil || len(animation.Frames) == 0 {
		return -1
	}
	if len(animation.Frames) == 1 {
		return 0
	}
	var duration time.Duration
	for _, frame := range animation.Frames {
		if frame.Delay > math.MaxInt64-duration {
			duration = math.MaxInt64
			break
		}
		duration += frame.Delay
	}
	if duration <= 0 {
		return 0
	}
	elapsed %= duration
	if elapsed < 0 {
		elapsed += duration
	}
	for index, frame := range animation.Frames {
		if elapsed < frame.Delay {
			return index
		}
		elapsed -= frame.Delay
	}
	return len(animation.Frames) - 1
}

func FirstMNGPNGFrame(data []byte) ([]byte, error) {
	animation, err := ParseMNG(data)
	if err != nil {
		return nil, err
	}
	return append([]byte(nil), animation.Frames[0].PNG...), nil
}
