package cli

import (
	"bytes"
	"errors"
	"strings"
	"testing"
)

func TestRun(t *testing.T) {
	for _, tc := range []struct {
		name string
		args []string
		code int
		out  string
		err  string
	}{
		{"no arguments", nil, 0, "Usage:", ""},
		{"help", []string{"--help"}, 0, "Usage:", ""},
		{"short help", []string{"-h"}, 0, "Usage:", ""},
		{"version", []string{"--version"}, 0, "development skeleton", ""},
		{"check cannot report success", []string{"check", "npm", "example", "--json"}, 2, "", "check is not implemented"},
		{"install cannot report success", []string{"install", "npm", "example"}, 2, "", "install is not implemented"},
		{"unknown command", []string{"unknown"}, 2, "", "unsupported command"},
		{"unexpected help argument", []string{"--help", "extra"}, 2, "", "unsupported command"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var stdout, stderr bytes.Buffer
			if code := Run(tc.args, &stdout, &stderr); code != tc.code {
				t.Fatalf("exit code = %d, want %d", code, tc.code)
			}
			for _, stream := range []struct{ got, want string }{{stdout.String(), tc.out}, {stderr.String(), tc.err}} {
				if (stream.want == "" && stream.got != "") || !strings.Contains(stream.got, stream.want) {
					t.Errorf("stream = %q, want %q", stream.got, stream.want)
				}
			}
		})
	}
}

type failingWriter struct{}

func (failingWriter) Write([]byte) (int, error) { return 0, errors.New("closed output") }

func TestOutputFailure(t *testing.T) {
	for _, args := range [][]string{{"--help"}, {"--version"}} {
		var stderr bytes.Buffer
		if code := Run(args, failingWriter{}, &stderr); code != 1 {
			t.Fatalf("exit code = %d, want 1", code)
		}
	}
}
