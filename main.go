package main

import (
	"fmt"
	"log"
	"os"

	"github.com/smpanaro/time-series-compression/compress"
	"github.com/smpanaro/time-series-compression/evaluate"
	"github.com/urfave/cli/v2"
)

func main() {
	app := &cli.App{
		Name:  "time-series-compression",
		Usage: "test time series compression techniques",
		Commands: []*cli.Command{
			{
				Name:  "evaluate",
				Usage: "[algorithm] [path]",
				Flags: []cli.Flag{
					&cli.StringFlag{
						Name:     "method",
						Aliases:  []string{"a", "m"},
						Usage:    "one of: " + compress.AllMethods.Join(", "),
						Required: true,
					},
					&cli.BoolFlag{
						Name:    "interleave",
						Aliases: []string{"i"},
						Usage:   "interleave timestamps and values before compressing. typically leads to worse results. does not apply to Gorilla. default: false",
					},
					&cli.StringFlag{
						Name:     "path",
						Aliases:  []string{"p"},
						Usage:    "path to an uncompressed data file",
						Required: true,
					},
				},
				Action: func(c *cli.Context) error {
					algorithm := compress.Method(c.String("method"))
					if !compress.AllMethods.Contains(algorithm) {
						return fmt.Errorf("invalid method: %s. must be one of: %v", algorithm, compress.AllMethods.Strings())
					}

					evaluation, err := evaluate.NewEvaluation(algorithm, c.Bool("interleave"), c.String("path"))
					if err != nil {
						return err
					}

					result, err := evaluation.Run()
					if err != nil {
						return err
					}

					result.PrintStats()

					return nil
				},
			},
		},
	}

	if err := app.Run(os.Args); err != nil {
		log.Fatal(err)
	}
}
