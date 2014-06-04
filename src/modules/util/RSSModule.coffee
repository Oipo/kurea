module.exports = (Module) ->

	FeedSub = require "feedsub"
	shorturl = require "shorturl"
	_ = require "underscore"
	_.str = require "underscore.string"
	color = require "irc-colors"

	class RSSModule extends Module
		shortName: "RSS"
		helpText:
			default: "Watch an RSS feed and send updates to the channel!"
		usage:
			default: "rss [title] <interval=10 (minutes)> [url]"

		feeds: {}

		constructor: (moduleManager) ->
			super moduleManager

			generateKey = (origin, key) =>
				origin.bot.config.server + origin.channel + key

			rss = (origin, url, title, interval=10) =>
				if !_.str.include url, "http"
					@reply origin, "You need to specify a valid URL."
					return

				newFeed = new FeedSub url,
					interval: interval

				newFeed.on "item", (item) =>
						shorturl item.link, (shorturl) =>
						@reply origin, "[#{color.bold title}] (#{shorturl}) #{item.title}"

				@feeds[generateKey origin,title] = newFeed

				newFeed.start()

				@reply origin, "I am now watching #{title} (#{url}) for posts."

			@addRoute "rss :title :interval *", (origin, route) =>
				interval = parseInt route.params.interval
				if not interval
					@reply origin, "Your interval is invalid, try again."
					return

				rss origin, route.splats[0], route.params.title, interval

			@addRoute "rss :title *", (origin, route) =>
				rss origin, route.splats[0], route.params.title

	RSSModule