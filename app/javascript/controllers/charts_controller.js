import {Controller} from "@hotwired/stimulus";
import ApexCharts from "apexcharts"
import humanizeDuration from "humanize-duration";

const formatTypes = ["number", "time"]
const chartTypes = ["area", "line", "stacked-bar", "donut"]
const chartColors = [
  "#1A56DB", "#9061F9", "#E74694", "#31C48D", "#FDBA8C", "#16BDCA",
  "#7E3BF2", "#1C64F2", "#F05252"
];

export default class extends Controller {
  static targets = ["chart"]

  static values = {
    type: String,
    format: {type: String, default: "number"},
    areaNames: Array,
    areaSeries: Array,
    areaCategories: Array,
    lineNames: Array,
    lineSeries: Array,
    lineCategories: Array,
    stackedBarNames: Array,
    stackedBarSeries: Array,
    stackedBarCategories: Array,
    donutNames: Array,
    donutSeries: Array,
    donutLabel: String,
  }

  initialize() {
    const chartType = this.typeValue

    if (!chartTypes.includes(chartType)) {
      console.error('Invalid chart type.')
      return;
    }

    if (!formatTypes.includes(this.formatValue)) {
      console.error('Invalid data format type.')
      return;
    }

    let names = []
    let series = []
    let categories = []
    let label
    let chartOptions

    if (chartType === "area") {
      names = this.areaNamesValue
      series = this.areaSeriesValue
      categories = this.areaCategoriesValue
      chartOptions = this.areaOptions(names, series, categories)
    } else if (chartType === "line") {
      names = this.lineNamesValue
      series = this.lineSeriesValue
      categories = this.lineCategoriesValue
      chartOptions = this.lineOptions(names, series, categories)
    } else if (chartType === "donut") {
      label = this.donutLabelValue;
      names = this.donutNamesValue;
      series = this.donutSeriesValue;
      chartOptions = this.donutOptions(names, series, label)
    } else if (chartType === "stacked-bar") {
      names = this.stackedBarNamesValue
      series = this.stackedBarSeriesValue
      categories = this.stackedBarCategoriesValue
      chartOptions = this.stackedBarOptions(names, series, categories)

      if (!this.__validateStackBarData(names, series, categories)) {
        return
      }
    }

    if (chartType !== "stacked-bar" && !this.__validateData(names, series, categories)) {
      return;
    }

    this.chart = new ApexCharts(this.chartTarget, chartOptions);
    this.chart.render();
  }

  areaOptions(names, series, categories) {
    let self = this;

    return {
      chart: {
        height: "100%",
        maxWidth: "100%",
        width: "100%",
        type: "area",
        fontFamily: "Inter, sans-serif",
        dropShadow: {
          enabled: false,
        },
        toolbar: {
          show: false,
        },
      },
      tooltip: {
        enabled: true,
        x: {
          show: false,
        },
        y: {
          formatter(val) {
            if (self.__isTimeFormat()) {
              return self.__formatSeconds(val)
            } else {
              return val
            }
          },
        },
      },
      fill: {
        type: "gradient",
        gradient: {
          opacityFrom: 0.55,
          opacityTo: 0,
          shade: "#1C64F2",
          gradientToColors: ["#1C64F2"],
        },
      },
      dataLabels: {
        enabled: false,
      },
      stroke: {
        width: 6,
      },
      grid: {
        show: false,
        strokeDashArray: 4,
        padding: {
          left: 2,
          right: 2,
          top: 0
        },
      },
      series: this.__genSeries(names, series),
      xaxis: {
        categories: categories,
        tickPlacement: 'between',
        labels: {
          show: true,
        },
        axisBorder: {
          show: false,
        },
        axisTicks: {
          show: false,
        },
      },
      yaxis: {
        show: false,
      },
    }
  }

  lineOptions(names, series, categories) {
    let self = this;

    return {
      chart: {
        height: "100%",
        maxWidth: "100%",
        type: "line",
        fontFamily: "Inter, sans-serif",
        dropShadow: {
          enabled: false,
        },
        toolbar: {
          show: false,
        },
      },
      tooltip: {
        enabled: true,
        x: {
          show: false,
        },
        y: {
          formatter(val) {
            if (self.__isTimeFormat()) {
              return self.__formatSeconds(val)
            } else {
              return val
            }
          },
        },
      },
      dataLabels: {
        enabled: false,
      },
      grid: {
        show: true,
        strokeDashArray: 4,
        padding: {
          left: 2,
          right: 2,
          top: -20
        },
      },
      series: this.__genSeries(names, series),
      legend: {
        show: false
      },
      stroke: {
        width: 3,
        curve: 'smooth'
      },
      xaxis: {
        categories: categories,
        tickPlacement: 'between',
        labels: {
          show: true,
          style: {
            fontFamily: "Inter, sans-serif",
            cssClass: 'text-xs font-normal fill-gray-500'
          }
        },
        axisBorder: {
          show: true,
        },
        axisTicks: {
          show: true,
        },
      },
      yaxis: {
        show: false,
      },
    }
  }

  donutOptions(names, series, label) {
    return {
      series: series,
      colors: chartColors,
      chart: {
        height: 320,
        width: "100%",
        type: "donut",
      },
      stroke: {
        colors: ["transparent"],
        lineCap: "",
      },
      plotOptions: {
        pie: {
          donut: {
            labels: {
              show: true,
              name: {
                show: true,
                fontFamily: "Inter, sans-serif",
                offsetY: 20,
              },
              total: {
                showAlways: true,
                show: true,
                label: label,
                fontFamily: "Inter, sans-serif",
                formatter: function (w) {
                  const sum = w.globals.seriesTotals.reduce((a, b) => {
                    return a + b
                  }, 0)
                  return `${sum}`
                },
              },
              value: {
                show: true,
                fontFamily: "Inter, sans-serif",
                offsetY: -20,
              },
            },
            size: "80%",
          },
        },
      },
      grid: {
        padding: {
          top: -2,
        },
      },
      labels: names,
      dataLabels: {
        enabled: false,
      },
      legend: {
        position: "bottom",
        fontFamily: "Inter, sans-serif",
      },
      xaxis: {
        axisTicks: {
          show: false,
        },
        axisBorder: {
          show: false,
        },
      },
    }
  }

  stackedBarOptions(names, series, categories) {
    let self = this;

    return {
      series: this._genBarSeries(names, series, categories),
      chart: {
        type: "bar",
        stacked: true,
        stackType: "100%",
        height: "100%",
        fontFamily: "Inter, sans-serif",
        toolbar: {
          show: false,
        },
      },
      plotOptions: {
        bar: {
          horizontal: false,
          columnWidth: "70%",
          borderRadiusApplication: "end",
          borderRadius: 8,
        },
      },
      tooltip: {
        shared: true,
        intersect: false,
        style: {
          fontFamily: "Inter, sans-serif",
        },
        y: {
          formatter(val) {
            if (self.__isTimeFormat()) {
              return self.__formatSeconds(val)
            } else {
              return val
            }
          },
        },
      },
      states: {
        hover: {
          filter: {
            type: "darken",
            value: 1,
          },
        },
      },
      stroke: {
        show: true,
        width: 0,
        colors: ["transparent"],
      },
      grid: {
        show: false,
        strokeDashArray: 4,
        padding: {
          left: 2,
          right: 2,
          top: -14
        },
      },
      dataLabels: {
        enabled: false,
      },
      legend: {
        show: false,
      },
      xaxis: {
        categories: categories,
        floating: true,
        labels: {
          show: true,
          style: {
            fontFamily: "Inter, sans-serif",
            cssClass: 'text-xs font-normal fill-gray-500'
          }
        },
        axisBorder: {
          show: false,
        },
        axisTicks: {
          show: false,
        },
      },
      yaxis: {
        show: false,
      },
      fill: {
        opacity: 1,
      },
    }
  }

  __genSeries(names, data) {
    let outputData = [];

    for (let i = 0; i < names.length; i++) {
      const formattedData = data[i].map((item) => (item === null ? 0 : item));
      const entry = {
        name: names[i],
        data: formattedData,
        color: this.__pickColor(i)
      };

      outputData.push(entry);
    }

    return outputData;
  }

  _genBarSeries(names, series, categories) {
    return names.map((name, index) => ({
      name,
      color: this.__pickColor(index),
      data: categories.map((xLabel, i) => (series[i][index])),
    }));
  }

  __pickColor(i) {
    const colorsLength = chartColors.length;
    const colorIndex = ((i % colorsLength) + colorsLength) % colorsLength;
    return chartColors[colorIndex];
  }

  __validateData(names, series, categories) {
    if (names.length !== series.length) {
      console.error('Names and Series must have the same number of top-level items.');
      return false;
    }

    if (categories.length > 0 && series.some(dataset => dataset.length !== categories.length)) {
      console.error('Categories and each dataset in the Series must be equal in size');
      return false;
    }

    return true;
  }

  __validateStackBarData(names, series, categories) {
    if (categories.length !== series.length) {
      console.error('Categories and Series must have the same number of top-level items.');
      return false;
    }

    if (names.length > 0 && series.some(dataset => dataset.length !== names.length)) {
      console.error('Names and each dataset in the Series must be equal in size');
      return false;
    }

    return true;
  }

  __formatSeconds(seconds) {
    return humanizeDuration(seconds * 1000, { round: true, largest: 2, maxDecimalPoints: 1 })
  }

  __isTimeFormat() {
    return this.formatValue === "time"
  }
}
