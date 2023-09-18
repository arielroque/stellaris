package dashboard

import (
	"html/template"
	"log"
	"time"
)

const markup = `
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Stellaris</title>
    <!-- Include Bootstrap CSS -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css">
    <style>
        :root {
            --primary-color: #BEDA1A;
            --secondary-color: #2F2F2F;
            --accent-color: #48C792;
        }

        .navbar {
            background-color: var(--primary-color);
        }

        .navbar-brand {
            font-size: 24px;
        }

        .table-primary {
            background-color: var(--primary-color);
        }

        .table-secondary {
            background-color: var(--secondary-color);
        }

        .table-accent {
            background-color: var(--accent-color);
        }

        .error {
            color: red;
        }

        .right {
            text-align: right;
        }
    </style>
</head>

<body>
    <nav class="navbar navbar-expand-lg navbar-dark">
        <div class="container">
            <a class="navbar-brand" href="#"> 
            <img src="https://github.com/arielroque/stellaris/blob/developer/images/icon.png" alt="Stellaris Logo" width="50">
            <span class="ml-2">Stellaris</span>
            </a>
        </div>
    </nav>

    {{if .Err}}
    <div class="container mt-5">
        <div class="error">Stellaris server unavailable. Check connection...</div>
    </div>
    {{end}}

    <div class="container mt-5">
        <h4>Realtime data</h4>
        <table class="table table-bordered">
            <caption class="right">Last Updated: {{.LastUpdated.Format "Jan 2 15:04:05"}}</caption>
            <thead>
                <tr>
                    <th class="table-secondary">Sensor</th>
                    <th class="table-secondary">Status</th>
                    <th class="table-secondary">Time</th>
                </tr>
            </thead>
            <tbody>
                {{range .Data}}
                <tr>
                    <td>{{.Sensor}}</td>
                    {{if .Time}}
                    <td>{{.Status | printf "%.2f"}}</td>
                    <td class="center">{{.Time.Format "15:04:05"}}</td>
                    {{else}}
                    <td>-</td>
                    <td>-</td>
                    {{end}}
                </tr>
                {{end}}
            </tbody>
        </table>
    </div>
    <footer class="text-white" style="background-color: var(--secondary-color);">
        <div class="container py-4">
          <p>&copy; 2023 Stellaris. All rights reserved.</p>
        </div>
      </footer>
    <!-- Include Bootstrap JS and Popper.js -->
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>

    <script>
            function refresh() {
                window.location.reload(true);
            }
            setTimeout(refresh, 1000);
    </script>      
</body>

</html>
`

// Page is the dashboard page template already parsed.
var Page *template.Template

// Data represent a data for a specific Sensor in a specific time.
type Data struct {
	Sensor string
	Status float64
	Time   *time.Time
}

func init() {
	var err error
	Page, err = template.New("dashboard").Parse(markup)
	if err != nil {
		log.Fatal(err)
	}
}
