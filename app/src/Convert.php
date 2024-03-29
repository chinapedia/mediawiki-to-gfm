<?php

namespace App;

use Pandoc\Pandoc;
use App\CleanLink;
use App\PandocFix;

class Convert
{

    /**
     * Converter Version
     * @var string
     */
    private $version = '0.9.1';
    private $dataVersion = '';
    /**
     * Path and name of  file to convert
     * @var String
     */
    private $filename;

    /**
     * Path to directory to save converted files
     * @var String
     */
    private $output;
    private $outputTree;

    /**
     * Set to true will save converted files in one directory level
     * @var boolean
     */
    private $flatten = false;

    /**
     * Set to true will add a permalink in 'gfm' format to each converted file
     * @var boolean
     */
    private $addmeta = false;

    /**
     * Which format to convert files to.
     * @var string
     */
    private $format = 'gfm+raw_html';
    private $luafilter = '';
    private $template = '';

    /**
     * Holds the count of how many files converted
     * @var integer
     */
    private $counter = 0;

    /**
     * Holds XML Data for each 'page' found in the XML file
     * @var [type]
     */
    private $dataToConvert;

    /**
     * Holds instance of Pandoc
     * @var Object
     */
    private $pandoc;

    /**
     * Options for Pandoc object
     * @var Array
     */
    private $pandocOptions;

    /**
     * Set whether the version of pandoc in use contains a known link bug
     * @see // Link to bug on Github
     * @var [type]
     */
    private $pandocBroken;

    /**
     * Construct
     */
    public function __construct($options)
    {
        $this->pandoc = new Pandoc();
        $this->pandocBroken = (version_compare($this->pandoc->getVersion(), '2.0.2', '<='));
        $this->setArguments($options);
        $this->dataVersion = substr(file_get_contents($this->output . "VERSION"), 0, 8);
    }

    public function run()
    {
        $this->createDirectory($this->output);
        $this->pandocSetup();
        $this->loadData($this->loadFile());
        $this->convertData();
        $this->message("$this->counter files converted");
    }

    /**
     * Get instance and setup pandoc
     * @return
     */
    public function pandocSetup()
    {
        $this->pandocOptions = [
            "data-dir"  => "app",
            "wrap"  => "none",
            "from"  => "mediawiki",
            "to"    => $this->format
        ];
        if (! empty($this->luafilter)) {
            $this->pandocOptions["lua-filter"] = $this->luafilter;
        }

        if (! empty($this->template)) {
            $this->pandocOptions["template"] = $this->template;
        }
        $this->message("pandoc: " . json_encode($this->pandocOptions));
        $jsonFile = $this->output . "tree.json";
        if (file_exists($jsonFile)) {
            $tree = json_decode(file_get_contents($jsonFile), true); 
            $this->outputTree = [];
            $dirTree = $tree[0]['contents'];
            foreach ($dirTree as $dir ) {
                $d = [];
                if (!empty($dir['contents'])) {
                    foreach ($dir['contents'] as $r) {
                        $d[$r['name']] = true;
                    }
                }
                $this->outputTree[$dir['name']] = $d;
            }
            echo json_encode($this->outputTree);
        }
    }

    /**
     * Method to oversee the cleaning, preparation and converting of one page
     */
    public function convertData()
    {
        foreach ($this->dataToConvert as $node) {
            $title = $node->xpath('title');
            $fileMeta = $this->retrieveFileInfo($title);
            if (empty($fileMeta) || 201 == ($fileMeta['type']) || ($fileMeta['type']) <= 0) {
                $this->message("ignore slash: " . $title . ": " . json_encode($fileMeta));
                continue;
            }
            
            $text = $node->xpath('revision/text')[0];
            if (empty($text)) {
                continue;
            }

            if ($fileMeta['type'] == 3 || $fileMeta['type'] == 4 || $fileMeta['type'] == 7) {
                if (strlen($text) > 1024) {
                    $this->saveFile($fileMeta, $text, ".wikitext");
                } else {
                    $this->message("Template: " . json_encode($fileMeta) . " -> " . $text);
                }
                continue;
            } else if ($fileMeta['type'] == 200) {
                $draftpath = $this->output . "Draft/" . $fileMeta['filename'] . ".md";
                @unlink($draftpath);
            }
            
            $text = $this->cleanText($text, $fileMeta);
            if (empty($text)) {
                $this->message("cleanText empty: " . json_encode($fileMeta));
                continue;
            }

            if ($this->format === "mediawiki") {
                $this->saveFile($fileMeta, $text, ".wikitext");
                continue;
            }

            try {
                $lang = getenv("WIKILANG");
                $this->message("pandoc: {$fileMeta['filename']}: ");
                $errpath=$this->output . "Errors/" . $fileMeta['filename'];
                $procOpt = [];
                $procOpt["stdout"] = $errpath . ".log";
                $procOpt["stderr"] = $errpath . ".err.log";
                $procOpt["timeout"] = 3;
                if ($lang == "en" || mb_strlen($text) > 16*1024) {
                    $procOpt["timeout"] = 6;
                }
                $this->pandocOptions["variable"] = [
                    "\"cfmtitle={$fileMeta['title']}\"",
                    "\"cfmurl={$fileMeta['url']}\"",
                    "\"WIKILANG={$lang}\"",
                    "\"stdout={$errpath}.log\""
                ];
                
                file_put_contents($errpath . ".wikitext", $text);
                $this->runPandoc($text, $procOpt);
                $text = file_get_contents($procOpt["stdout"]);
                @unlink($procOpt["stdout"]);
                $stderr = file_get_contents($procOpt["stderr"]);
                if (mb_strlen($stderr) > 0) {
                    $this->message("Caught stderr {$fileMeta['filename']}: ", $stderr);
                } else {
                    @unlink($procOpt["stderr"]);
                }
                if (empty($text)) {
                    continue;
                }
                @unlink($errpath . ".wikitext");
            } catch (\Throwable $e) {
                $errmsg=$e->getMessage();
                $this->message("Caught exception {$fileMeta['filename']}: ", $errmsg);
                continue;
            }
            $text .= $this->getMetaData($fileMeta);
            $this->saveFile($fileMeta, $text);
            $this->counter++;
        }
    }

    public function mapping($mappingFile, $key, $value) {
        $tree = json_decode(file_get_contents($mappingFile), true);
        $tree[$key] = $value;
        file_put_contents($mappingFile, json_encode($tree, JSON_PRETTY_PRINT)); 
    }

    /**
     * Handles the various tasks to clean and get text ready to convert
     * @param  string $text Text to convert
     * @param  array $fileMeta File information
     * @return string Cleaned text
     */
    public function cleanText($text, $fileMeta)
    {
        $callback = new cleanLink($this->flatten, $fileMeta);
        $callbackFix = new pandocFix();

        // decode inline html
        $text = html_entity_decode($text);

        if (mb_strpos($text, "#") === 0) {
            $ext=".md";
            $target="";
            if (mb_stripos($text, "#REDIRECT") === 0) {
                $target = mb_substr($text, mb_strlen("#REDIRECT"));
            } else if (mb_strpos($text, "#重定向") === 0) {
                $target = mb_substr($text, mb_strlen("#重定向"));
            }

            $fileName = $fileMeta['filename'] . $ext;
            if (mb_strlen($target) > 4) {
                if ($fileMeta['type']<200) {
                    $source = $fileMeta['directory'] . $fileName;
                    unlink($source);
                    file_put_contents(
                        $this->output . "Redirect/" . $this->dataVersion . ".tsv",
                        $source . "\t" . $target . "\n",
                        FILE_APPEND);
                    return null;
                }
                $matches = [];
                preg_match('/\[\[(.*)\]\]/', $target, $matches, PREG_OFFSET_CAPTURE);
                if (count($matches)>1) {
                    $dir="Page";
                    $mobj=$matches[1];
                    if ($this->format === "mediawiki") {
                        $dir = mb_substr($mobj[0],0,1);
                        $ext = ".wikitext";
                    }
                    $targetName = str_replace(' ', '_', $mobj[0]);
                    $targetFile = $dir . "/" . $targetName . $ext;
                    if ($fileMeta['type']>=200 && file_exists($this->output . $targetFile)) {
                        $this->message("Redirect: " . $fileMeta['filename'] . " -> " . $targetFile);
                        if (array_key_exists($fileName, $this->outputTree['Redirect'])) {
                            unlink($this->output . "Redirect/" . $fileName);
                        }
                        if (getenv("WIKILANG") == "en") {
                            $this->mapping(
                                $this->output . "Redirect/" . mb_substr($fileName, 0, 1) . ".json",
                                $fileMeta['filename'],
                                $targetName 
                            );
                        } else {
                            symlink("../" . $targetFile, $this->output . "Redirect/" . $fileName);
                        }
                    } else {
                        $this->message("Redirect target not exists: " . $text . $targetFile);
                    }

                    $lagacyFile = $this->output . $dir . $fileName;
                    if ($this->outputTree[$dir] && array_key_exists($fileName, $this->outputTree[$dir]) && filesize($lagacyFile) < 2048) {
                        @unlink($lagacyFile);
                        $this->message("Delete lagacy page: " . $lagacyFile);
                    } else {
                        $this->message("Skip lagacy page: ", $lagacyFile);
                    }
                    return null;
                }
            }
            $this->message("Ignroe redirect: " . $text);
            return null;
        }
        
        $pageMinSize=1024;
        if (getenv("WIKILANG") == "en") {
            $pageMinSize*=16;
        }
        if (mb_strlen($text) < $pageMinSize) {
            $lagacyFile = $this->output . $fileMeta['directory'] . $fileMeta['filename'] . ".md";
            if (@filesize($lagacyFile) < 2048) {
                @unlink($lagacyFile);
            }
            $this->message("Delete short page: ", $lagacyFile);
            return null;
        }
        
        // Hack to fix URLs for older version of pandoc
        if ($this->pandocBroken) {
            $text = preg_replace_callback('/\[(http.+?)\]/', [$callbackFix, 'urlFix'], $text);
        }

        // clean up links
        $text = preg_replace_callback('/\[\[(.+?)\]\]/', [$callback, "cleanLink"], $text);
        // remove comments
        return preg_replace('/<!--(.|\s)*?-->/', '', $text);
    }

    /**
     * Run pandoc and do the actual conversion
     * @param  string $text Text to convert
     * @return string Converted Text
     */
    public function runPandoc($text, $procOpt)
    {
        if ($this->pandocOptions["from"] === $this->pandocOptions["to"]) {
            return $text;
        }
        
        $text = $this->pandoc->runWith($text, $this->pandocOptions, $procOpt);
        $text = str_replace('\_', '_', $text);

        return $text;
    }

   /**
     * Save new mark down file
     * @param  string $fileMeta Name of file to save
     * @param  strong $text     Body of file to save
     */
    public function saveFile($fileMeta, $text, $ext=".md")
    {
        $this->createDirectory($fileMeta['directory']);
        if(getenv("WIKILANG")!='en' && mb_detect_encoding($text,"UTF-8, ISO-8859-1, GBK")!="UTF-8") {
            $text = iconv("gbk","utf-8",$text);
            $this->message("Text encoding: " . $text);
        }
        $file = fopen($fileMeta['directory'] . $fileMeta['filename'] . $ext, 'w');
        if ($file) {
            fwrite($file, $text);
            fclose($file);

            $this->message("Converted: " . $fileMeta['directory'] . $fileMeta['filename']);
        } else {
            $this->message("Failed to write file: " . $fileMeta['directory'] . $fileMeta['filename']);
        }
    }

    /**
     * Build array of file information
     * @param  array $title Title of current page to convert
     * @return array File information: Directory, filename, title and url
     */
    public function retrieveFileInfo($title)
    {
        $title = (string)$title[0];
        $url = str_replace(' ', '_', $title);
        $filename = $url;
        $filename = str_replace("&", "@", $filename);
        $directory = '';
        $type = 200;

        $specialPages = ["Wikipedia", "Help", "Category", "Module", "Template", "File", "Portal", "MediaWiki", "Draft", "WikiProject", 
                                                                      "ファイル"];
        $pageType = -1;
        foreach ($specialPages as $sp) {
            $pageType += 1;
            if (0 === mb_strpos(strtolower($title), strtolower($sp . ":"))) {
                $type = $pageType;
                $directory = $sp . "/";
                $filename = mb_substr($filename, mb_strlen($directory));
                $filename = str_replace('/', '_', $filename);
                if ($sp === "File") {
                    return null;
                }
                if ($sp === "ファイル") { // File for ja
                    return null;
                }
                break;
            }
        }

        if ($type >= 200) {
            if ($slash = mb_strpos($url, '/')) {
                $title = str_replace('/', ' ', $title);
                $filename = $title;
                $directory = "Page/";
                $type = 201;
            } else {
                if ($this->format === "mediawiki") {
                    $directory = mb_substr($url, 0, 1) . '/';
                } else if (empty($directory)) {
                    $directory = "Page/";
                }
                $type = 203;
            }
        }

        $directory = $this->output . $directory;

        return [
            'type' => $type,
            'directory' => $directory,
            'filename' => $filename,
            'title' => $title,
            'url' => $url
        ];
    }

    /**
     * Simple method to handle outputing messages to the CLI
     * @param  string $message Message to output
     */
    public function message($message)
    {
        echo $message . PHP_EOL;
    }

    /**
     * Build and return Permalink metadata
     * @param array $fileMeta File Title and URL
     * @return  string Page body with meta data added
     */
    public function getMetaData($fileMeta)
    {
        return ($this->addmeta)
            ? sprintf("---\ntitle: %s\npermalink: /%s/\n---\n\n", $fileMeta['title'], $fileMeta['url'])
            : '';
    }

    public function loadFile()
    {
        if (!file_exists($this->filename)) {
            throw new \Exception('Input file does not exist: ' . $this->filename);
        }

        echo ("Loading " . $this->filename . "\n");
        $file = file_get_contents($this->filename);
        echo ("Loaded: " . $this->filename . " L:" . strlen($file) . "\n");

        return str_replace('xmlns=', 'ns=', $file); //$string is a string that contains xml...
    }

    /**
     * Load XML contents into variable
     */
    public function loadData($xml)
    {
        if (($xml = new \SimpleXMLElement($xml, LIBXML_COMPACT | LIBXML_PARSEHUGE)) === false) {
            throw new \Exception('Invalid XML File.');
        }
        $this->dataToConvert = $xml->xpath('page');

        if ($this->dataToConvert == '') {
            throw new \Exception('XML Data is empty');
        }
    }

    /**
     * Get command line arguments into variables
     * @param  array $argv Array hold command line interface arguments
     */
    public function setArguments($options)
    {
        $this->setOption('filename', $options, null);
        $this->setOption('output', $options, 'output');
        $this->setOption('format', $options, $this->pandocBroken ? 'markdown_github' : 'gfm+raw_html');
        $this->setOption('flatten', $options);
        $this->setOption('addmeta', $options);
        $this->setOption('luafilter', $options);
        $this->setOption('template', $options);
        $this->output = rtrim($this->output, '/') . '/';
    }

    /**
     * Set an Option
     * @param string $name  Option name
     * @param string $value Option value
     */
    public function setOption($name, $options, $default = false)
    {
        $this->{$name} = (isset($options[$name]) ? (empty($options[$name]) ? true : $options[$name]) : $default);
    }

    /**
     * Helper method to cleanly create a directory if none already exists
     * @param string $output Returns path
     */
    public function createDirectory($directory = null)
    {
        if (!empty($directory) && !file_exists($directory)) {
            if (!mkdir($directory, 0755, true)) {
                throw new \Exception('Unable to create directory: ' . $directory);
            }
        }
        return $directory;
    }

    /**
     * Get Option
     * @param string $name  Option name
     * @param string $value Option value
     */
    public function getOption($name)
    {
        return $this->{$name};
    }

    /**
     * Get Version
     */
    public function getVersion()
    {
        echo "Version: {$this->version}";
    }
    /**
     * Basic help instructions
     */
    public function help()
    {
        echo <<<HELPMESSAGE
Version: {$this->version}
MIT License: https://opensource.org/licenses/MIT

Mediawiki to GFM converter is a script that will convert a set of media wiki
files to Github Flavoured Markdown (GFM). This converter has been tested to work
with Mediawiki 1.27.x and 1.29.x.

Requirements:
    pandoc: Installation instructions are here https://pandoc.org/installing.html
            Tested on version 2.0.1.1 and 2.0.2 
    mediawiki: https://www.mediawiki.org/wiki/MediaWiki
               Tested on version 1.27.x and 1.29.x

Run the script on your exported MediaWiki XML file:
    ./convert.php --filename=/path/to/filename.xml 

Options:
    ./convert.php --filename=/path/to/filename.xml --output=/path/to/converted/files --format=gfm --addmeta --flatten 

    --filename : Location of the mediawiki exported XML file to convert to GFM format (Required).
    --output   : Location where you would like to save the converted files (Default: ./output).
    --format   : What format would you like to convert to. Default is GFM (for use 
        in Gitlab and Github) See pandoc documentation for more formats (Default: 'gfm').
    --addmeta  : This flag will add a Permalink to each file (Default: false).
    --flatten  : This flag will force all pages to be saved in a single level 
                 directory. File names will be converted in the following way:
                 Mediawiki_folder/My_File_Name -> Mediawiki_folder_My_File_Name
                 and saved in a file called 'Mediawiki_folder_My_File_Name.md'
    --help     : This help message.


Export Mediawiki Files to XML
In order to convert from MediaWiki format to GFM and use in Gitlab (or Github), you will 
first need to export all the pages you wish to convert from Mediawiki into an XML file. 
Here are a few simple steps to help
you accomplish this quickly:

    1. MediaWiki -> Special Pages -> 'All Pages'
    2. With help from the filter tool at the top of 'All Pages', copy the page names
       to convert into a text file (one file name per line).
    3. MediaWiki -> Special Pages -> 'Export'
    4. Paste the list of pages into the Export field. 
       Note: This convert script will only do latest version, not revisions. 
    5. Check: 'Include only the current revision, not the full history' 
    6. Uncheck: Include Templates
    7. Check: Save as file
    8. Click on the 'Export' button.

In theory you can convert to any of these formats… but this haven't been tested:
    https://pandoc.org/MANUAL.html#description

HELPMESSAGE;
    }
}
