#!/usr/bin/env bb
;; Rewrite nix/pins.json from the upstream release manifests at
;; releases.herdr.dev. No tarball downloads: each manifest already carries the
;; url and sha256 of every platform build.
(ns bump
  (:require
   [babashka.http-client :as http]
   [babashka.process :refer [shell]]
   [cheshire.core :as json]
   [clojure.string :as str]))

(def pins-path "nix/pins.json")

(def releases (or (System/getenv "HERDR_RELEASES_URL") "https://releases.herdr.dev"))

;; package -> manifest path under the release server.
(def packages
  (sorted-map
   "herdr-core" "core/latest.json"
   "herdr-app" "app/latest.json"))

;; Upstream target -> Nix system. Targets not listed (Windows) are ignored.
(def target->system
  {"linux-aarch64" "aarch64-linux"
   "linux-x86_64" "x86_64-linux"
   "macos-aarch64" "aarch64-darwin"
   "macos-x86_64" "x86_64-darwin"})

(defn- fail! [msg]
  (binding [*out* *err*]
    (println (str "error: " msg)))
  (System/exit 1))

(defn- fetch-json!
  "GET url and parse it. Exits 1 naming the url on non-2xx."
  [url]
  (let [resp (http/get url {:throw false})]
    (if (<= 200 (:status resp) 299)
      (json/parse-string (:body resp))
      (fail! (str "GET " url " -> HTTP " (:status resp))))))

(defn- sri-hash [hex]
  (-> (shell {:out :string} "nix" "hash" "convert" "--hash-algo" "sha256" "--to" "sri" hex)
      :out
      str/trim))

(defn- pin-of
  "The pin for one manifest: its version, and url + SRI hash for each Nix system."
  [manifest]
  (let [sources (into (sorted-map)
                      (for [[target {:strs [url sha256]}] (get manifest "targets")
                            :let [system (target->system target)]
                            :when system]
                        (if (and url sha256)
                          [system (sorted-map "hash" (sri-hash sha256) "url" url)]
                          (fail! (str "manifest entry " target " lacks url or sha256")))))]
    (cond-> (sorted-map "sources" sources "version" (get manifest "version"))
      (get manifest "core_min") (assoc "core_min" (get manifest "core_min")))))

(defn- version-parts [v]
  (mapv parse-long (str/split (first (str/split v #"-")) #"\.")))

(defn- older? [a b]
  (neg? (compare (version-parts a) (version-parts b))))

(defn- write-pretty-json! [path data]
  (spit path (str (json/generate-string data {:pretty true}) "\n")))

(let [dry-run? (some #{"--dry-run"} *command-line-args*)
      pins (json/parse-string (slurp pins-path))
      pins' (into (sorted-map)
                  (for [[pkg path] packages]
                    [pkg (pin-of (fetch-json! (str releases "/" path)))]))
      core (get-in pins' ["herdr-core" "version"])
      core-min (get-in pins' ["herdr-app" "core_min"])]
  ;; The app refuses a core older than its core_min; a pin pair that breaks
  ;; that would build and then fail at run time.
  (when (and core-min (older? core core-min))
    (fail! (str "herdr-core " core " is older than herdr-app's core_min " core-min)))
  (doseq [pkg (keys packages)
          :let [old (get-in pins [pkg "version"])
                new (get-in pins' [pkg "version"])]]
    (println (cond
               (= (get pins pkg) (get pins' pkg)) (str pkg ": unchanged")
               (= old new) (str pkg ": " new " (hashes changed)")
               :else (str pkg ": " old " -> " new))))
  (when (and (not dry-run?) (not= pins pins'))
    (write-pretty-json! pins-path pins')))
