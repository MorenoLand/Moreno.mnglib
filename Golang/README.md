# Go MNG support

This directory contains `tmng`, a standalone Go package with an MNG parser, PNG frame extractor, and elapsed-time frame selector. It uses only the Go standard library.

## Usage

```go
package main

import (
	"bytes"
	"image/png"
	"log"
	"os"
	"time"

	tmng "github.com/MorenoLand/Moreno.mnglib/Golang"
)

func main() {
	data, err := os.ReadFile("image.mng")
	if err != nil {
		log.Fatal(err)
	}
	animation, err := tmng.ParseMNG(data)
	if err != nil {
		log.Fatal(err)
	}
	frame := animation.Frames[animation.FrameIndexAt(250*time.Millisecond)]
	img, err := png.Decode(bytes.NewReader(frame.PNG))
	if err != nil {
		log.Fatal(err)
	}
	log.Println(len(animation.Frames), frame.Delay, img.Bounds())
}
```

## API

- `IsMNG(data)` checks the MNG signature.
- `ParseMNG(data)` returns a `*TMNGAnimation` with the MHDR fields and `Frames`, or an error for malformed input.
- `FirstMNGPNGFrame(data)` returns a copy of the first embedded PNG frame.
- `TMNGAnimation.FrameIndexAt(elapsed)` selects the looping frame for an elapsed `time.Duration`; it returns -1 when there are no frames and 0 when the total delay is 0.
- `TMNGFrame.PNG` is a complete PNG file, so `image/png` can decode it. `TMNGFrame.Delay` is a `time.Duration`.

Frames without a FRAM delay last 100 ms. FRAM delays follow `change_interframe_delay`: 1 applies to the next frame only, 2 also becomes the default for later frames, and any other value changes nothing. Delays are converted with the MHDR ticks per second (100 when the field is 0) and saturate at 4294967295 ms. Chunk CRCs are not verified.

## Build

```sh
cd Golang
go vet ./...
go build ./...
```

Built and vetted with Go 1.24.7, including `GOARCH=386`. `go.mod` declares `go 1.12`; the package also builds with Go 1.11.13 and 1.12.17.
