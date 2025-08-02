package qcow2convert

// #include <stdio.h>
// #include <errno.h>
import "C"
import (
	"fmt"
	"io"
	"os"
	"path/filepath"

	"github.com/cheggaaa/pb/v3"
	"github.com/containerd/continuity/fs"
	"github.com/docker/go-units"
	"github.com/lima-vm/go-qcow2reader"
	"github.com/lima-vm/go-qcow2reader/convert"
	"github.com/lima-vm/go-qcow2reader/image"
	"github.com/lima-vm/go-qcow2reader/image/qcow2"
	"github.com/lima-vm/go-qcow2reader/image/raw"
	"github.com/lima-vm/lima/pkg/progressbar"
	"github.com/sirupsen/logrus"
)

type ProgressCallback interface {
	// ProgressCallback is called with the current progress and total size.
	// The progress is a value between 0 and 1, where 0 means no progress and 1 means complete.
	ProgressCallback(readed int64, totalSize int64)
}

type proxyReaderAt struct {
	io.ReaderAt
	totalSize   int64
	totalReaded int64
	progress    ProgressCallback
}

func (r *proxyReaderAt) ReadAt(p []byte, off int64) (int, error) {
	n, err := r.ReaderAt.ReadAt(p, off)
	r.totalReaded += int64(n)

	if r.progress != nil {
		r.progress.ProgressCallback(r.totalReaded, r.totalSize)
	}

	return n, err
}

type QCow2Converter struct {
	source      string
	destination string
	stdout      int32
	progress    ProgressCallback
}

func NewQCow2Converter(source, destination string, outputFileHandle int32, progress ProgressCallback) *QCow2Converter {
	return &QCow2Converter{
		source:      source,
		destination: destination,
		stdout:      outputFileHandle,
		progress:    progress,
	}
}

func (q *QCow2Converter) makeSparse(f *os.File, n int64) error {
	if _, err := f.Seek(n, io.SeekStart); err != nil {
		return err
	}
	return f.Truncate(n)
}

func (q *QCow2Converter) convertRawToRaw(source, dest string, size *int64) error {
	if source != dest {
		// continuity attempts clonefile
		if err := fs.CopyFile(dest, source); err != nil {
			return fmt.Errorf("failed to copy %q into %q: %w", source, dest, err)
		}
	}
	if size != nil {
		logrus.Infof("Expanding to %s", units.BytesSize(float64(*size)))

		destF, err := os.OpenFile(dest, os.O_RDWR, 0o644)

		if err != nil {
			return err
		}

		if err = q.makeSparse(destF, *size); err != nil {
			_ = destF.Close()
			return err
		}

		return destF.Close()
	}

	return nil
}

// ConvertToRaw converts a source disk into a raw disk.
// source and dest may be same.
// ConvertToRaw is a NOP if source == dest, and no resizing is needed.
func (q *QCow2Converter) convertToRaw(source, dest string, size *int64, allowSourceWithBackingFile bool) (err error) {
	var destTmpF *os.File
	var srcF *os.File
	var srcImg image.Image
	var bar *pb.ProgressBar
	var conv *convert.Converter

	if srcF, err = os.Open(source); err != nil {
		return
	}

	defer srcF.Close()

	if srcImg, err = qcow2reader.Open(srcF); err != nil {
		return fmt.Errorf("failed to detect the format of %q: %w", source, err)
	}

	if size != nil && *size < srcImg.Size() {
		return fmt.Errorf("specified size %d is smaller than the original image size (%d) of %q", *size, srcImg.Size(), source)
	}

	switch t := srcImg.Type(); t {
	case raw.Type:
		if err = srcF.Close(); err != nil {
			return err
		}
		return q.convertRawToRaw(source, dest, size)

	case qcow2.Type:
		if !allowSourceWithBackingFile {
			if q, ok := srcImg.(*qcow2.Qcow2); ok {
				if q.BackingFile != "" {
					return fmt.Errorf("qcow2 image %q has an unexpected backing file: %q", source, q.BackingFile)
				}
			} else {
				return fmt.Errorf("unexpected qcow2 image %T", srcImg)
			}
		}

	default:
		return fmt.Errorf("image %q has an unexpected format: %q", source, t)
	}

	if err = srcImg.Readable(); err != nil {
		return fmt.Errorf("image %q is not readable: %w", source, err)
	}

	// Create a tmp file because source and dest can be same.
	if destTmpF, err = os.CreateTemp(filepath.Dir(dest), filepath.Base(dest)+".lima-*.tmp"); err != nil {
		return
	}

	destTmp := destTmpF.Name()

	defer os.RemoveAll(destTmp)
	defer destTmpF.Close()

	// Truncating before copy eliminates the seeks during copy and provide a
	// hint to the file system that may minimize allocations and fragmentation
	// of the file.
	if err = q.makeSparse(destTmpF, srcImg.Size()); err != nil {
		return
	}

	// Copy
	if bar, err = progressbar.New(srcImg.Size()); err != nil {
		return
	}

	if conv, err = convert.New(convert.Options{}); err != nil {
		return
	}

	bar.Start()

	err = conv.Convert(destTmpF, &proxyReaderAt{
		ReaderAt:    srcImg,
		totalSize:   srcImg.Size(),
		totalReaded: 0,
		progress:    q.progress,
	}, srcImg.Size())

	bar.Finish()

	if err != nil {
		return fmt.Errorf("failed to convert image: %w", err)
	}

	// Resize
	if size != nil {
		logrus.Infof("Expanding to %s", units.BytesSize(float64(*size)))

		if err = q.makeSparse(destTmpF, *size); err != nil {
			return
		}
	}

	if err = destTmpF.Close(); err != nil {
		return
	}

	// Rename destTmp into dest
	if err = os.RemoveAll(dest); err != nil {
		return
	}

	return os.Rename(destTmp, dest)
}

func (q *QCow2Converter) Convert() int32 {
	if q.stdout > 0 {
		os.Stdout = os.NewFile(uintptr(q.stdout), "/dev/stdout")
		os.Stderr, _ = os.OpenFile(os.DevNull, os.O_WRONLY, 0)
		logrus.SetOutput(os.Stdout)
	}

	if err := q.convertToRaw(q.source, q.destination, nil, true); err != nil {
		os.Stderr.WriteString(err.Error())
		return -1
	}

	return 0
}
