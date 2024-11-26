package qcow2convert

// #include <stdio.h>
// #include <errno.h>
import "C"
import (
	"os"

	"github.com/lima-vm/lima/pkg/nativeimgutil"
)

// ConvertQCow2Raw
func ConvertQCow2Raw(src, dst *C.char, sizeInMb, stdout, stderr int32) int32 {
	var size int64 = int64(sizeInMb) * 1024

	if stdout > 0 {
		os.Stdout = os.NewFile(uintptr(stdout), "/dev/stdout")
	}

	if stderr > 0 {
		os.Stderr = os.NewFile(uintptr(stderr), "/dev/stderr")
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
	stderr      int32
}

func NewQCow2Converter(source, destination string, outputFileHandle, errorFileHandle int32) *QCow2Converter {
	return &QCow2Converter{
		source:      source,
		destination: destination,
		stdout:      outputFileHandle,
		stderr:      errorFileHandle,
	}
}

func (q *QCow2Converter) Convert() int32 {
	if q.stdout > 0 {
		os.Stdout = os.NewFile(uintptr(q.stdout), "/dev/stdout")
	}

	if q.stderr > 0 {
		os.Stderr = os.NewFile(uintptr(q.stderr), "/dev/stderr")
	}

	if err := nativeimgutil.ConvertToRaw(q.source, q.destination, nil, true); err != nil {
		os.Stderr.WriteString(err.Error())
		return -1
	}

	return 0
}
