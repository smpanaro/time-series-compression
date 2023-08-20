package series

import (
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestPoint_Interleaved(t *testing.T) {
	pts := Points{
		{
			Time:  time.UnixMilli(1_000),
			Value: 40,
		},
		{
			Time:  time.UnixMilli(2_000),
			Value: 50,
		},
		{
			Time:  time.UnixMilli(3_000),
			Value: 60,
		},
	}

	interleaved := pts.Interleaved()
	// Values are converted to milli (*1000) and zigzag encoded.
	expected := []uint64{
		uint64(1_000),
		uint64(ZigZagEncode64(40_000)),
		uint64(2_000),
		uint64(ZigZagEncode64(50_000)),
		uint64(3_000),
		uint64(ZigZagEncode64(60_000)),
	}
	assert.Equal(t, expected, interleaved)
}

func TestPoint_Split(t *testing.T) {
	pts := Points{
		{
			Time:  time.UnixMilli(1_000),
			Value: 10,
		},
		{
			Time:  time.UnixMilli(2_000),
			Value: 20,
		},
		{
			Time:  time.UnixMilli(3_000),
			Value: 30,
		},
	}

	split := pts.Split()
	expected := []uint64{
		uint64(1_000),
		uint64(2_000),
		uint64(3_000),
		uint64(ZigZagEncode64(10_000)),
		uint64(ZigZagEncode64(20_000)),
		uint64(ZigZagEncode64(30_000)),
	}

	assert.Equal(t, expected, split)
}

func TestPoint_FromSplit(t *testing.T) {
	pts := Points{
		{
			Time:  time.UnixMilli(1_000),
			Value: 10,
		},
		{
			Time:  time.UnixMilli(2_000),
			Value: 20,
		},
		{
			Time:  time.UnixMilli(3_000),
			Value: 30,
		},
	}

	split := pts.Split()
	unsplit := FromSplit(split)

	assert.Equal(t, unsplit, pts)
}

func TestPoint_DeltaEncoded(t *testing.T) {
	pts := Points{
		{
			Time:  time.UnixMilli(1_000),
			Value: 10,
		},
		{
			Time:  time.UnixMilli(1_500),
			Value: 15,
		},
		{
			Time:  time.UnixMilli(3_000),
			Value: 25,
		},
		{
			Time:  time.UnixMicro(3_100_500),
			Value: 8,
		},
	}

	deltaEncoded := pts.DeltaEncoded(true, true)
	expected := Points{
		{
			Time:  time.UnixMilli(1_000),
			Value: 10,
		},
		{
			Time:  time.UnixMilli(500),
			Value: 5,
		},
		{
			Time:  time.UnixMilli(1_500),
			Value: 10,
		},
		{
			Time:  time.UnixMilli(100),
			Value: -17,
		},
	}

	assert.Equal(t, len(expected), len(deltaEncoded))
	for i := range expected {
		assert.Equal(t, expected[i].Time, deltaEncoded[i].Time)
		assert.Equal(t, expected[i].Value, deltaEncoded[i].Value)
	}
}

func TestPoint_DeltaDecoded(t *testing.T) {
	pts := Points{
		{
			Time:  time.UnixMilli(1_000),
			Value: 10,
		},
		{
			Time:  time.UnixMilli(1_500),
			Value: 15,
		},
		{
			Time:  time.UnixMilli(3_000),
			Value: 25,
		},
		{
			Time:  time.UnixMicro(3_100_500),
			Value: 8,
		},
	}

	encoded := pts.DeltaEncoded(true, true)
	decoded := encoded.DeltaDecoded(true, true)

	assert.Equal(t, len(decoded), len(pts))
	for i := range decoded {
		assert.Equal(t, decoded[i].Time.UnixMilli(), pts[i].Time.UnixMilli())
		assert.Equal(t, decoded[i].Value, pts[i].Value)
	}
}

func TestZigZagEncode(t *testing.T) {
	nums := []int16{-22, -123, -350}
	for _, n := range nums {
		enc := ZigZagEncode16(n)
		dec := ZigZagDecode16(enc)
		assert.Equal(t, n, dec)
		fmt.Printf("n: %d enc: %016b\n", n, enc)
	}
}

func ZigZagEncode16(n int16) uint16 {
	return uint16(uint16(n<<1) ^ uint16(int16(n)>>15))
}

func ZigZagDecode16(n uint16) int16 {
	return int16((n >> 1) ^ uint16((int16(n&1)<<15)>>15))
}
