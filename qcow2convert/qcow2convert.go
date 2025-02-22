package qcow2convert

// #include <stdio.h>
// #include <errno.h>
import "C"
import (
	"os"

	"github.com/lima-vm/lima/pkg/nativeimgutil"
	"github.com/sirupsen/logrus"
)

// ConvertQCow2Raw
func ConvertQCow2Raw(src, dst *C.char, sizeInMb, stdout int32) int32 {
	var size int64 = int64(sizeInMb) * 1024

	if stdout > 0 {
		os.Stdout = os.NewFile(uintptr(stdout), "/dev/stdout")
		os.Stderr, _ = os.OpenFile(os.DevNull, os.O_WRONLY, 0)
		logrus.SetOutput(os.Stdout)
	}

	if err := nativeimgutil.ConvertToRaw(C.GoString(src), C.GoString(dst), &size, true); err != nil {
		os.Stderr.WriteString(err.Error())
		return -1
	}

	return int32(size / 1024)
}

type QCow2Converter struct {
	source      string
	destination string
	stdout      int32
}

func NewQCow2Converter(source, destination string, outputFileHandle int32) *QCow2Converter {
	return &QCow2Converter{
		source:      source,
		destination: destination,
		stdout:      outputFileHandle,
	}
}

func (q *QCow2Converter) Convert() int32 {
	if q.stdout > 0 {
		os.Stdout = os.NewFile(uintptr(q.stdout), "/dev/stdout")
		os.Stderr, _ = os.OpenFile(os.DevNull, os.O_WRONLY, 0)
		logrus.SetOutput(os.Stdout)
	}

	if err := nativeimgutil.ConvertToRaw(q.source, q.destination, nil, true); err != nil {
		os.Stderr.WriteString(err.Error())
		return -1
	}

	return 0
}
