from zen_backend import create_app

app = create_app()


def main() -> None:
	app.run(host="0.0.0.0", port=app.config.get("PORT", 5000), debug=False)


if __name__ == "__main__":
	main()
